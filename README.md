# RBWS

*really bad web ~~server~~service*

this is mostly for self-hosting my personal website, frykman.dev.
use at your own peril.

## Examples

### Basic usage

The following is a really basic web server that simply loads files from the disk and logs the responses.

```dart
import 'package:rbws/rbws.dart';
import 'dart:io';

void main() async {
    HTTPServerInstance server = HTTPServerInstance(InternetAddress.anyIPv4, 80, generalServeRoot: "/path/to/webroot");
    server.onResponse = (response) {
        print("${DateTime.now()} ${response.toRequest?.path} [${response.status}]");
    };

    server.start();
}
```

We could build on top of that by also providing static routes, which will match before trying to load a file.
The following code is the same as last time, but we have a super secret webpage that checks for a password as a cookie.

```dart
import 'package:rbws/rbws.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
    HTTPServerInstance server = HTTPServerInstance(InternetAddress.anyIPv4, 80, generalServeRoot: "/path/to/webroot");
    server.onResponse = (response) {
        print("${DateTime.now()} ${response.toRequest?.path} [${response.status}]");
    };

    // This can also be defined as an optional parameter in the constructor!
    server.staticRoutes = {
        (RBWSMethod.get, "/super-secret-webpage"): (request) {
            if(!request.headers.containsKey["Cookie"]) {
                return RBWSResponse(401, data: utf8.encode("401 Unauthorized"), headers: {"Content-Type": "text/plain"});
            }

            List<String> cookies = request.headers["Cookie"].split(" ");
            if(cookies.isEmpty) {
                return RBWSResponse(401, data: utf8.encode("401 Unauthorized"), headers: {"Content-Type": "text/plain"});
            }

            for(String cookie in cookies) {
                if(cookie.startsWith("password") && cookie.trim().split("=").last == "ImNotTheFBI") {
                    return RBWSResponse(200, data: utf8.encode("<h1>EVIDENCE:</h1><img src='evidence.jpeg' />"), headers: {"Content-Type": "text/html"});
                }
            }
            return RBWSResponse(401, data: utf8.encode("401 Unauthorized"), headers: {"Content-Type": "text/plain"});
        }
    };

    server.start();
}
```

### Insecure -> Secure upgrader

The following is the same as the last example, but the insecure version offers to upgrade HTTP to HTTPS and only offers the "/super-secret-webpage" over HTTPS.

```dart
import 'package:rbws/rbws.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
    HTTPServerInstance secureServer = HTTPServerInstance(InternetAddress.anyIPv4, 443, generalServeRoot: "/path/to/webroot", securityContext: SecurityContext.defaultContext);
    secureServer.securityContext!.useCertificateChain("/path/to/certificate");
    secureServer.securityContext!.usePrivateKey("/path/to/private/key");

    HTTPServerInstance server = HTTPServerInstance(InternetAddress.anyIPv4, 80, generalServeRoot: "/path/to/webroot");  
    server.referralToSecureServer = "https://${secureServer.host.address}:${secureServer.port}"; // This will trigger Upgrade-Insecure-Requests: 1

    var onResponse = (response) {
        print("${DateTime.now()} ${response.toRequest?.path} [${response.status}]");
    };

    server.onResponse = onResponse;
    secureServer.onResponse = onResponse;

    // This can also be defined as an optional parameter in the constructor!
    secureServer.staticRoutes = {
        (RBWSMethod.get, "/super-secret-webpage"): (request) {
            if(!request.headers.containsKey["Cookie"]) {
                return RBWSResponse(401, data: utf8.encode("401 Unauthorized"), headers: {"Content-Type": "text/plain"});
            }

            List<String> cookies = request.headers["Cookie"].split(" ");
            if(cookies.isEmpty) {
                return RBWSResponse(401, data: utf8.encode("401 Unauthorized"), headers: {"Content-Type": "text/plain"});
            }

            for(String cookie in cookies) {
                if(cookie.startsWith("password") && cookie.trim().split("=").last == "ImNotTheFBI") {
                    return RBWSResponse(200, data: utf8.encode("<h1>EVIDENCE:</h1><img src='evidence.jpeg' />"), headers: {"Content-Type": "text/html"});
                }
            }
            return RBWSResponse(401, data: utf8.encode("401 Unauthorized"), headers: {"Content-Type": "text/plain"});
        }
    };

    secureServer.start();
    server.start();
}
```
