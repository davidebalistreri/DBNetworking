//
//  DBNetworking.swift
//  App Design course
//
//  Created by Davide Balistreri on 02/08/2018.
//  Updated on 02/04/2022.
//  Copyright © 2018. All rights reserved.
//

import Foundation

/**
 * Modulo creato per semplificare le chiamate alle web API con Swift e iOS.
 *
 * Esempio per ottenere una stringa:
 * ```
 * let string = await DBNetworking
 *     .request(url: "https://www.google.it")
 *     .response().body
 * ```
 */
public struct DBNetworking {
    
    /**
     * Crea un oggetto `DBNetworking.Request` da utilizzare per inviare una richiesta web con i parametri specificati.
     *
     * - Parameter url: L'indirizzo dell'API da richiamare.
     * - Parameter type: Il tipo di richiesta HTTP (default: GET).
     * - Parameter authToken: Il token di autenticazione (facoltativo).
     * - Parameter parameters: I parametri da inviare al server (facoltativi).
     * - Parameter multipartFiles: I file da inviare al server in multipart (facoltativi).
     * - Parameter configuration: La configurazione da utilizzare per effettuare la richiesta (default: utilizza la cache).
     * - Returns: Un oggetto `DBNetworking.Request` da utilizzare per inviare la richiesta e ottenere la risposta (vedi esempi).
     *
     * Per effettuare una chiamata web, si crea una richiesta con questa funzione `DBNetworking.request()`.
     * Successivamente utilizzando la funzione `response()` si invia la richiesta e si riceve la risposta.
     *
     * È possibile serializzare automaticamente la risposta ricevuta in un generico oggetto `NSDictionary` o una `String`;
     * utile ad esempio quando non si possiede una `struct` o una `class` modellata come i dati che ci invierà il server:
     * ```
     * let weatherRequest = DBNetworking.request(
     *     url: "https://edu.davidebalistreri.it/app/v2/weather",
     *     parameters: [
     *         "lat": 41.89,
     *         "lng": 12.49,
     *         "appid": "OpenWeatherMap-AppId",
     *     ])
     *
     * let weatherResponse = await weatherRequest
     *     .response(type: NSDictionary.self)
     * ```
     *
     * Se invece si possiede un modello conforme al protocollo `Decodable`, è possibile utilizzarlo per serializzare la risposta ricevuta.
     * È possibile ottenere la risposta anche con un singolo passaggio, creando la `request` e chiedendo direttamente la `response`.
     * ```
     * let login = await DBNetworking
     *     .request(
     *         url: "https://edu.davidebalistreri.it/app/v2/login",
     *         type: .post,
     *         parameters: [
     *             "email": "my@email.it",
     *             "password": "password",
     *         ])
     *     .response(type: ResponseModel<UserModel>.self)
     * ```
     *
     * Per ottenere una semplice stringa:
     * ```
     * let string = await DBNetworking
     *     .request(url: "https://www.google.it")
     *     .response().body
     * ```
     *
     * Per controllare solamente se una richiesta è andata a buon fine:
     * ```
     * let success = await DBNetworking
     *     .request(url: "https://www.google.it")
     *     .response().success
     * ```
     *
     * Per modificare il token di autenticazione dopo aver creato una richiesta:
     * ```
     * let userRequest = DBNetworking.request(
     *     url: "https://edu.davidebalistreri.it/app/v2/user")
     *
     * let userResponse = await userRequest
     *     .setAuthToken("AmydY57cen3KLrlvUGZrCpziw81w")
     *     .response(type: ResponseModel<UserModel>.self)
     * ```
     */
    public static func request(
        url urlString: String,
        type: RequestType = .get,
        authToken: String? = nil,
        parameters: [String: Any]? = nil,
        multipartFiles: [MultipartFile]? = nil,
        configuration: URLSessionConfiguration = .default
    ) -> Request {
        // Request URL
        guard let url = URL(string: urlString) else {
            return Request(error: URLError(.badURL))
        }
        
        var urlRequest = URLRequest(url: url)
        
        // Request type
        switch type {
        case .get:
            urlRequest.httpMethod = "GET"
        case .post, .multipartPost:
            urlRequest.httpMethod = "POST"
        case .put:
            urlRequest.httpMethod = "PUT"
        case .delete:
            urlRequest.httpMethod = "DELETE"
        }
        
        // Content type
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Parameters
        if parameters == nil || parameters?.isEmpty == true {
            // No parameters
        }
        else if type == .get || type == .delete {
            var queryItems: [URLQueryItem] = []
            
            for (key, value) in parameters ?? [:] {
                queryItems.append(URLQueryItem(name: key, value: "\(value)"))
            }
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            urlRequest.url = components?.url ?? urlRequest.url
        }
        else if type == .post || type == .multipartPost {
            // Form-data
            let boundaryUUID = UUID().uuidString
            let boundaryString = "Boundary-" + boundaryUUID
            
            urlRequest.setValue("multipart/form-data; boundary=" + boundaryString, forHTTPHeaderField: "Content-Type")
            
            // Inserisco i parametri specificati
            urlRequest.httpBody = makeBody(with: parameters, boundaryString: boundaryString, multipartFiles: multipartFiles)
        }
        else if type == .put {
            let body = parameters?.map { "\($0.key)=\($0.value)" }
            urlRequest.httpBody = body?.joined(separator: "&").data(using: .utf8)
        }
        
        let session = URLSession(configuration: configuration)
        
        return Request(urlRequest: urlRequest, urlSession: session)
            .setAuthToken(authToken)
    }
    
    private static func makeBody(
        with parameters: [String: Any]?,
        boundaryString: String,
        multipartFiles: [MultipartFile]?
    ) -> Data {
        let body = NSMutableData()
        
        let boundaryPrefix = "--" + boundaryString + "\r\n"
        
        if let parameters = parameters {
            for (key, value) in parameters {
                append(string: boundaryPrefix, to: body)
                append(string: "Content-Disposition: form-data; name=\"" + key + "\"\r\n\r\n", to: body)
                append(string: "\(value)\r\n", to: body)
            }
        }
        
        for multipartFile in multipartFiles ?? [] {
            append(string: boundaryPrefix, to: body)
            
            if let parameter = multipartFile.parameterName, let name = multipartFile.fileName {
                append(string: "Content-Disposition: form-data; name=\"" + parameter + "\"; filename=\"" + name + "\"\r\n", to: body)
            }
            
            if let mimeType = multipartFile.mimeType {
                append(string: "Content-Type: " + mimeType + "r\n\r\n", to: body)
            }
            
            if let data = multipartFile.data {
                body.append(data)
            }
            
            append(string: "\r\n", to: body)
            append(string: "--" + boundaryString + "--", to: body)
        }
        
        return body as Data
    }
    
    // Per semplificare la conversione di stringhe in bytes
    private static func append(string: String, to: NSMutableData) {
        if let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            to.append(data)
        }
    }
    
    // Supporta async/await anche prima di iOS 15
    private static func execute(
        _ request: URLRequest,
        with session: URLSession
    ) async throws -> (Data?, URLResponse?) {
        if #available(iOS 15.0, *) {
            // New API
            return try await session.data(for: request)
        }
        
        // Fallback on earlier versions
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(Data?, URLResponse?), Error>) in
            let task = session.dataTask(with: request) { data, response, error in
                guard let data = data, let response = response else {
                    let error = error ?? URLError(.badServerResponse)
                    return continuation.resume(throwing: error)
                }
                
                continuation.resume(returning: (data, response))
            }
            
            task.resume()
        }
    }
    
    /// Struttura utilizzata per inviare una richiesta web da questo modulo.
    public struct Request {
        
        /// Se presente, indica che la creazione della richiesta non è andata a buon fine.
        public let error: Error?
        
        public var urlRequest: URLRequest?
        public var urlSession: URLSession?
        
        /**
         * Invia la richiesta e serializza automaticamente la risposta ricevuta (per oggetti `Decodable`).
         *
         * - Parameter type: Il tipo di oggetto che ci si aspetta in risposta (String.self, UserModel.self, ecc).
         * - Returns: Un oggetto `DBNetworking.Response` contenente la risposta ricevuta (in `response.body`),
         *            oppure un errore (in `response.error`).
         *
         * Esempio di utilizzo:
         * ```
         * let response = await request.response(
         *     type: UserModel.self
         * )
         *
         * if response.success,
         *     let name = response.body?.firstName as? String {
         *     // Richiesta ok
         *     print("Nome: \(name)")
         * }
         * ```
         */
        public func response<T: Decodable>(type decodable: T.Type) async -> Response<T> {
            guard error == nil else {
                return Response(error: error!)
            }
            
            guard let request = urlRequest, let session = urlSession else {
                return Response(error: RequestError())
            }
            
            do {
                let (data, urlResponse) = try await DBNetworking.execute(request, with: session)
                
                var response = Response<T>()
                response.success = isSuccess(urlResponse)
                
                guard let data = data else {
                    // Nessun dato ricevuto
                    return response
                }
                
                // Converto i dati ricevuti dal server nel formato richiesto
                do {
                    if decodable is String.Type {
                        // L'oggetto richiesto è una stringa
                        response.body = String(data: data, encoding: .utf8) as? T
                    } else {
                        response.body = try JSONDecoder().decode(decodable, from: data)
                    }
                } catch {
                    response.error = error
                }
                
                return response
            }
            catch {
                return Response(error: error)
            }
        }
        
        /**
         * Invia la richiesta e serializza automaticamente la risposta ricevuta (per oggetti `Foundation`).
         *
         * - Parameter type: Il tipo di oggetto che ci si aspetta in risposta (NSDictionary.self, [String: Any].self, ecc).
         * - Returns: Un oggetto `DBNetworking.Response` contenente la risposta ricevuta (in `response.body`),
         *            oppure un errore (in `response.error`).
         *
         * Esempio di utilizzo:
         * ```
         * let response = await request.response(
         *     type: NSDictionary.self
         * )
         *
         * if response.success,
         *     let name = response.body?["name"] as? String {
         *     // Richiesta ok
         *     print("Nome: \(name)")
         * }
         * ```
         */
        public func response<T>(type foundationObject: T.Type) async -> Response<T> {
            guard error == nil else {
                return Response(error: error!)
            }
            
            guard let request = urlRequest, let session = urlSession else {
                return Response(error: RequestError())
            }
            
            do {
                let (data, urlResponse) = try await DBNetworking.execute(request, with: session)
                
                var response = Response<T>()
                response.success = isSuccess(urlResponse)
                
                guard let data = data else {
                    // Nessun dato ricevuto
                    return response
                }
                
                do {
                    // Converto i dati ricevuti dal server nel formato richiesto
                    response.body = try JSONSerialization.jsonObject(
                        with: data,
                        options: .fragmentsAllowed
                    ) as? T
                } catch {
                    response.error = error
                }
                
                return response
            }
            catch {
                return Response(error: error)
            }
        }
        
        /**
         * Invia la richiesta e serializza la risposta in una stringa.
         *
         * - Returns: Un oggetto `DBNetworking.Response` contenente la stringa ricevuta (in `response.body`),
         *            oppure un errore (in `response.error`).
         *
         * Utile se si vuole solamente controllare quando una richiesta va a buon fine:
         * ```
         * let response = await request.response()
         *
         * if response.success {
         *     print("Richiesta ok")
         * }
         * ```
         */
        @discardableResult
        public func response() async -> Response<String> {
            return await response(type: String.self)
        }
        
        /**
         * Modifica il token di autenticazione della richiesta.
         *
         * Utile per replicare la stessa richiesta con un token diverso, ad esempio per il refresh token.
         */
        @discardableResult
        public func setAuthToken(_ authToken: String?) -> Request {
            var urlRequest = self.urlRequest
            
            if let authToken = authToken {
                urlRequest?.setValue(authToken, forHTTPHeaderField: "Authorization")
            } else {
                urlRequest?.allHTTPHeaderFields?.removeValue(forKey: "Authorization")
            }
            
            return .init(urlRequest: urlRequest, urlSession: self.urlSession, error: self.error)
        }
        
        private func isSuccess(_ response: URLResponse?) -> Bool {
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            
            return true
        }
        
        // Costruttore privato
        fileprivate init(
            urlRequest: URLRequest? = nil,
            urlSession: URLSession? = nil,
            error: Error? = nil
        ) {
            self.urlRequest = urlRequest
            self.urlSession = urlSession
            self.error = error
        }
        
        public struct RequestError : Error { }
        
    }
    
    /// Struttura restituita in risposta alle richieste web effettuate da questo modulo.
    public struct Response<T> {
        
        /// Indica se la richiesta effettuata è andata a buon fine.
        public var success: Bool = false
        
        /// Se presente, indica che si è verificato un errore durante l'esecuzione della richiesta.
        public var error: Error?
        
        /// I dati ricevuti dal server, convertiti nel formato specificato.
        public var body: T?
        
    }
    
    /// I tipi di richieste HTTP supportati da questo modulo.
    public enum RequestType {
        case get
        case post
        case multipartPost
        case put
        case delete
    }
    
    /// Struttura da utilizzare per inviare un file in multipart da questo modulo.
    public struct MultipartFile {
        
        public let parameterName: String?
        
        public let fileName: String?
        
        public let mimeType: String?
        
        public let data: Data?
        
    }
    
    // Costruttore privato
    private init() { }
    
}
