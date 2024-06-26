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

  HTTPServerInstance server = HTTPServerInstance("localhost", 80, generalServeRoot: "example/public", onResponse: logResponseInsecure);
  server.referralToSecureServer = "https://localhost:443";

  HTTPServerInstance secure = HTTPServerInstance("localhost", 443, generalServeRoot: "example/public", onResponse: logResponseSecure, securityContext: SecurityContext.defaultContext);
  
  // BYOC (bring your own certificates)
  // If you don't already have your own certificate, theres a really good guide to generate one at https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/
  // When you're defining the SAN, set DNS.1 to localhost or to whatever you changed [host] to.
  secure.securityContext!.useCertificateChain("example/cert/localhost.crt");
  secure.securityContext!.usePrivateKey("example/cert/localhost.key");

  secure.staticRoutes = {(RBWSMethod.get, "/secure"): (req) => RBWSResponse.dataFromString(200, "This is being served from the secure server!", headers: {"Content-Type": "text/plain"})};
  secure.storage = server.storage;

  server.start();
  secure.start();
}