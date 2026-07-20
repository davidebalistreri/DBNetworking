import Foundation
import XCTest
@testable import DBNetworking

final class DBNetworkingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    func testResponseDataReturnsRawBodyAndHTTPResponse() async {
        let payload = Data([0x00, 0x01, 0xFF, 0x7F])
        StubURLProtocol.configure(status: 200, headers: ["X-Test": "raw"], body: payload)

        let response = await makeRequest().responseData()

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.body, payload)
        XCTAssertEqual((response.urlResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual((response.urlResponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Test"), "raw")
        XCTAssertNil(response.error)
    }

    func testResponseDataPreservesEmptyBody() async {
        StubURLProtocol.configure(status: 200, body: Data())

        let response = await makeRequest().responseData()

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.body, Data())
    }

    func testResponseDataPreservesBodyAndStatusForHTTPError() async {
        let payload = Data("not found".utf8)
        StubURLProtocol.configure(status: 404, body: payload)

        let response = await makeRequest().responseData()

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.body, payload)
        XCTAssertEqual((response.urlResponse as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertNil(response.error)
    }

    func testResponseDataReturnsTransportError() async {
        StubURLProtocol.configure(error: URLError(.notConnectedToInternet))

        let response = await makeRequest().responseData()

        XCTAssertFalse(response.success)
        XCTAssertNil(response.body)
        XCTAssertTrue(response.error is URLError)
        XCTAssertNil(response.urlResponse)
    }

    func testResponseDataUsesQueueScheduler() async {
        StubURLProtocol.configure(status: 200, body: Data([1]), delay: 0.05)

        async let first = makeRequest(queueKey: "binary-test").responseData()
        async let second = makeRequest(queueKey: "binary-test").responseData()
        let responses = await (first, second)

        XCTAssertTrue(responses.0.success)
        XCTAssertTrue(responses.1.success)
        XCTAssertEqual(StubURLProtocol.maximumConcurrentRequests, 1)
    }

    func testExistingStringResponseStillWorks() async {
        StubURLProtocol.configure(status: 200, body: Data("hello".utf8))

        let response = await makeRequest().response()

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.body, "hello")
        XCTAssertEqual((response.urlResponse as? HTTPURLResponse)?.statusCode, 200)
    }

    private func makeRequest(queueKey: String? = nil) -> DBNetworking.Request {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return DBNetworking.request(
            url: "stub://dbnetworking.test/resource",
            configuration: configuration,
            queueKey: queueKey
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var status = 200
    private static var headers: [String: String] = [:]
    private static var body = Data()
    private static var failure: Error?
    private static var delay: TimeInterval = 0
    private static var activeRequests = 0
    private(set) static var maximumConcurrentRequests = 0

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        status = 200
        headers = [:]
        body = Data()
        failure = nil
        delay = 0
        activeRequests = 0
        maximumConcurrentRequests = 0
    }

    static func configure(
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        delay: TimeInterval = 0
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.status = status
        self.headers = headers
        self.body = body
        self.failure = nil
        self.delay = delay
    }

    static func configure(error: Error) {
        lock.lock()
        defer { lock.unlock() }
        failure = error
        delay = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "stub"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let status = Self.status
        let headers = Self.headers
        let body = Self.body
        let failure = Self.failure
        let delay = Self.delay
        Self.activeRequests += 1
        Self.maximumConcurrentRequests = max(Self.maximumConcurrentRequests, Self.activeRequests)
        Self.lock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }

            if let failure {
                self.client?.urlProtocol(self, didFailWithError: failure)
            } else {
                let response = HTTPURLResponse(
                    url: self.request.url!,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: body)
                self.client?.urlProtocolDidFinishLoading(self)
            }

            Self.lock.lock()
            Self.activeRequests -= 1
            Self.lock.unlock()
        }
    }

    override func stopLoading() {}
}
