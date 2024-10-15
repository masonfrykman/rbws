# RBWS

*really bad web server*

Another generic HTTP/1.1 web server implementation using ```dart:io```.

## Features :D

- Matches request paths to files from a defined document root.
    - **To enable:** Set the ```generalServeRoot``` property on an ```HTTPServerInstance```.
- Stores files loaded from filesystem in a cache that will clear the file after an arbitrary amount of time.
    - The amount of time defaults to a day. The duration can be changed by setting ```defaultStorageLength```.
- Matches request paths to static handler functions.
    - **To enable:** Populate the ```staticRoutes``` map on an ```HTTPServerInstance```.
- Redirects insecure requests to a secure version.
    - **To enable:** Set ```referralToSecureServer``` on an ```HTTPServerInstance``` where ```securityContext == null```.
    - **Caveat:** Requests will only be upgraded if they have the header ```Upgrade-Insecure-Requests: 1```

## A note on the License

The RBWS package is licensed under the [GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.txt) (you can also find it in the LICENSE file of the GitHub repo)

**What this means for you:** you can use the pub utility to get the package, import it into another application, and release that code built on this library under whatever license your heart desires.

However, if any of the source code of this library is changed or reused, that subsequent source code must be released and be easily accessible under the LGPL or GPL. Thats it! :)

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
