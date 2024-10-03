## (TBD)
- Fixed server crash when request is malformed UTF8
    - Now responds with 400 Bad Request

## 1.1.0

- Made HTTPServerInstance more modular
    - Extracted Upgrade-Insecure-Requests handling into HTTPServerInstance.shouldUpgradeInsecureRequest
    - Extracted request -> method matching into HTTPServerInstance.matchRequestToMethodProcessFunction
- Fixed typos

## 1.0.0

- Initial version (rapid development phase)
