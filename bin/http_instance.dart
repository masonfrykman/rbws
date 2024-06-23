import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';

import 'http_request.dart';
import 'http_response.dart';

import 'autorelease_cache.dart';

class HTTPServerInstance {
  // *************************
  // * General Configuration *
  // *************************

  bool debug = false;

  dynamic host;
  int port;
  String? generalServeRoot;
  Map<(RBWSMethod, String), FutureOr<RBWSResponse> Function(RBWSRequest)>?
      staticRoutes;
  SecurityContext? securityContext;
  String? referralToSecureServer;

  // ****************
  // * Internal Use *
  // ****************

  AutoreleasingCache storage = AutoreleasingCache();
  dynamic _serverSocket;

  HTTPServerInstance(this.host, this.port,
      {this.generalServeRoot, this.staticRoutes, this.securityContext});

  void start() async {
    if (securityContext != null) {
      _serverSocket = await SecureServerSocket.bind(host, port, securityContext,
          supportedProtocols: ["http/1.1"]);
      _serverSocket!.listen((socket) => _secureSocketOnListen(socket));
      return;
    }
    _serverSocket = await ServerSocket.bind(host, port);
    _serverSocket!.listen((socket) => _insecureSocketOnListen(socket));
  }

  void _secureSocketOnListen(SecureSocket connection) {
    connection.setOption(SocketOption.tcpNoDelay, true);
    connection.listen((data) => _conOnData(data, connection));
  }

  void _insecureSocketOnListen(Socket connection) {
    connection.setOption(SocketOption.tcpNoDelay, true);
    connection.listen((data) => _conOnData(data, connection));
  }

  void _conOnData(Uint8List data, Socket sender) async {
    var req = RBWSRequest.from(data);
    if (req == null) {
      return;
    }

    var response = await processRequest(req!);
    sender.add(response.generate11WithData());
    await sender.flush(); // Make sure we don't start sending other data.
    sender.destroy();
    // I've been having issues where data isn't recieved by browsers until
    // the socket is destroyed. To be so for real, I have no idea if it's
    // supposed to be like that, but the existence of Connection: keep-alive
    // seems to point to the contrary. If someone has the answer, please let
    // me know!
  }

  Future<RBWSResponse> processRequest(RBWSRequest request) async {
    // Upgrade-Insecure-Requests
    if (securityContext == null &&
        request.headers["Upgrade-Insecure-Requests"]?.trim() == "1" &&
        referralToSecureServer != null) {
      return RBWSResponse(303, headers: {
        "Vary": "Upgrade-Insecure-Requests",
        "Location": "$referralToSecureServer${request.path}"
      });
    }

    // Check static routes
    var key = (request.method, request.path);
    if (staticRoutes != null && staticRoutes!.containsKey(key)) {
      var getStatic = await staticRoutes![key]!(request);
      if (debug) {
        getStatic.headers["x-dbg-route-type"] = "static";
      }
      return getStatic;
    }

    // Dynamically load from storage.
    if (generalServeRoot == null) {
      return RBWSResponse(404,
          data: utf8.encode("404 Not Found"),
          headers: {"Content-Type": "text/plain"});
    }

    var loadAttempt = await storage.grab("$generalServeRoot${request.path}",
        ifNotCachedClearAfter: Duration(days: 1));
    if (loadAttempt == null) {
      return RBWSResponse(404,
          data: utf8.encode("404 Not Found"),
          headers: {"Content-Type": "text/plain"});
    }
    return RBWSResponse(200, data: loadAttempt, headers: {
      "Content-Type": lookupMimeType(request.path) ?? "application/octet-stream"
    });
  }
}
