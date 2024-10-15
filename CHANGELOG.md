## (tbd)

- Made the HandshakeException description more useful.
- Errors with a server no longer cause the whole program to exit.
- Insecure servers now announce errors to stderr.

## 1.1.1
- Fixed where a malformed request causes server crash
    - Server now responds with 400 Bad Request

## 1.1.0

- Made HTTPServerInstance more modular
    - Extracted Upgrade-Insecure-Requests handling into HTTPServerInstance.shouldUpgradeInsecureRequest
    - Extracted request -> method matching into HTTPServerInstance.matchRequestToMethodProcessFunction
- Fixed typos

## 1.0.0

- Initial version (rapid development phase)
