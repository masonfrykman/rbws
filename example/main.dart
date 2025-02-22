import 'dart:convert';
import 'dart:io';

import 'package:rbws/rbws.dart';

void logResponse(RBWSResponse response) {
  print("${DateTime.now()}: [${response.status}] ${response.toRequest?.path}");
}

void logResponseSecure(RBWSResponse response) {
  stdout.write("[Secure]: ");
  logResponse(response);
}

void logResponseInsecure(RBWSResponse response) {
  stdout.write("[Insecure]: ");
  logResponse(response);
}

void main(List<String> args) async {
  print("Example public web server using RBWS.");

  // BYOC (bring your own certificates)
  // If you don't already have your own certificate, theres a really good guide to generate one at https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/
  // When you're defining the SAN, set DNS.1 to localhost or to whatever you changed [host] to.
  String? certChainPath, privateKeyPath;
  certChainPath = "example/cert/localhost.crt";
  privateKeyPath = "example/cert/localhost.key";
  // ^ comment these TWO lines out if you don't have a certificate
  //    it's taken care of below; don't remove the declarations.

  SecurityContext? context;
  if (certChainPath != null && privateKeyPath != null) {
    context = SecurityContext.defaultContext;
    context.useCertificateChain("example/cert/localhost.crt");
    context.usePrivateKey("example/cert/localhost.key");
  }

  HTTPServerInstance server = HTTPServerInstance("localhost", 80,
      generalServeRoot: "example/public", onResponse: logResponseInsecure);
  server.referralToSecureServer = "https://localhost:443";

  HTTPServerInstance secure = HTTPServerInstance("localhost", 443,
      generalServeRoot: "example/public",
      onResponse: logResponseSecure,
      securityContext: context);

  secure.staticRoutes = {
    (RBWSMethod.get, "/secure"): (req) => RBWSResponse.dataFromString(200,
        "This is being served from the secure server object${context == null ? "; however, the server is not configured to be secure, so it's being served insecurely anyways." : " securely!"}",
        headers: {"Content-Type": "text/plain"}),
    (RBWSMethod.post, "/stop"): (req) {
      if (req.data == null) {
        return RBWSResponse.dataFromString(403, "403 Forbidden");
      }
      if (utf8.decode(req.data!, allowMalformed: true).trim() ==
          "SuperSecretStopKey123") {
        secure.stop();
        server.stop();
        print(
            "Server stop request succeeded. The program will stop accepting connections but may not exit.");
        return RBWSResponse.dataFromString(200, "Server shutting down!");
      }
      return RBWSResponse.dataFromString(403, "403 Forbidden");
    },
  };
  secure.storage = server.storage;

  server.start();
  secure.start();
}
