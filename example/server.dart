import 'dart:io';

import 'package:rbws/rbws.dart';

void logResponse(RBWSResponse response) {
  print("[Insecure Server]: ${DateTime.now()}: [${response.status}] ${response.toRequest?.path}");  
}

void main(List<String> args) async {
  print("Example public web server using RBWS.");

  HTTPServerInstance server = HTTPServerInstance("localhost", 80, generalServeRoot: "example/public", onResponse: logResponse);
  server.referralToSecureServer = "https://localhost:443";
  
  server.staticRoutes = {
    (RBWSMethod.get, "/"): (req) async {
      var indexData = await server.storage.grab("example/public/index.html");
      if(indexData == null) {
        return RBWSResponse.dataFromString(404, "404 Not Found", headers: {"Content-Type": "text/plain"});
      }
      return RBWSResponse(200, data: indexData, headers: {"Content-Type": "text/html"});
    }
  };

  HTTPServerInstance secure = HTTPServerInstance("localhost", 443, generalServeRoot: "example/public", onResponse: logResponse, securityContext: SecurityContext.defaultContext);
  secure.securityContext!.useCertificateChain("example/cert/localhost.crt");
  secure.securityContext!.usePrivateKey("example/cert/localhost.key");
  secure.staticRoutes = server.staticRoutes;
  secure.staticRoutes![(RBWSMethod.get, "/secure")] = (req) => RBWSResponse.dataFromString(200, "This is being served from the secure server!", headers: {"Content-Type": "text/plain"});
  secure.storage = server.storage;

  server.start();
  secure.start();
}