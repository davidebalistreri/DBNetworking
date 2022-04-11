# DBNetworking

Modulo creato per semplificare le chiamate alle web API classiche con Swift e iOS.

```swift
let string = await DBNetworking
    .request(url: "https://www.google.it")
    .response().body
```


## Features

- [x] Swift Concurrency support
- [x] Automatic response decoding
- [x] Multipart POST
- [x] Repeatable requests


## Requirements

iOS 13.0 or later


## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/davidebalistreri/dbnetworking.git", .upToNextMajor(from: "1.0.1"))
]
```

### Manual installation
Drop the `DBNetworking.swift` file into your project, and you are ready to go.


## Usage

Per effettuare una chiamata web, si crea una richiesta con la funzione `DBNetworking.request()`.
Successivamente con la funzione `response()` si invia la richiesta e si riceve la risposta.

È possibile serializzare automaticamente la risposta ricevuta in un generico oggetto `NSDictionary` o una `String`,
utile ad esempio quando non si possiede una `struct` o una `class` modellata come i dati che ci invierà il server:
```swift
let weatherRequest = DBNetworking.request(
    url: "https://edu.davidebalistreri.it/app/v2/weather",
    parameters: [
        "lat": 41.89,
        "lng": 12.49,
        "appid": "OpenWeatherMap-AppId",
    ])

let weatherResponse = await weatherRequest
    .response(type: NSDictionary.self)
```

Se invece si possiede un modello conforme al protocollo `Decodable`, è possibile utilizzarlo per serializzare la risposta ricevuta.
È possibile ottenere la risposta anche con un singolo passaggio, creando la `request` e chiedendo direttamente la `response`.
```swift
let login = await DBNetworking
    .request(
        url: "https://edu.davidebalistreri.it/app/v2/login",
        type: .post,
        parameters: [
            "email": "my@email.it",
            "password": "password",
        ])
    .response(type: ResponseModel<UserModel>.self)
```


## Other usages

Per ottenere una semplice stringa:
```swift
let string = await DBNetworking
    .request(url: "https://www.google.it")
    .response().body
```

Per controllare solamente se una richiesta è andata a buon fine:
```swift
let success = await DBNetworking
    .request(url: "https://www.google.it")
    .response().success
```

Per modificare il **token di autenticazione** dopo aver creato una richiesta:
```swift
let userRequest = DBNetworking.request(
    url: "https://edu.davidebalistreri.it/app/v2/user")

let userResponse = await userRequest
    .setAuthToken("AmydY57cen3KLrlvUGZrCpziw81w")
    .response(type: ResponseModel<UserModel>.self)
```
