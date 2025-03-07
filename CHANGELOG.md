# (next major)

- **Breaking**: HTTPServerInstance.host and HTTPServerInstance.port now throw ServerRunningException in their setters if the server is running.
- Added ServerRunningException

# (next minor)

- Added HTTPStatusCode, a class that contains a bunch of static integer variables to neatly represent HTTP status codes inline.

## 1.2.0

- Deprecated RBWSMethod.unrecognized, will be removed in next major release.
- Added functions to AutoreleasingCache
    - contains
    - clear
    - setNewExpiration
    - replace
- Added exception type for when a path in AutoreleasingCache does not exist yet was attempted to be read. (not breaking anything yet!)

## 1.1.3

- Fixed header parse behavior
    - No longer adds trailing carriage returns
    - Ignores empty headers

## 1.1.2

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
