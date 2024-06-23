import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';

import 'http_helpers/http_request.dart';
import 'http_helpers/http_response.dart';

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

  dynamic Function(RBWSRequest)? onRequest;
  dynamic Function(RBWSResponse)? onResponse;
  FutureOr<RBWSResponse> Function(RBWSRequest) routeNotFound = (r) {
    return RBWSResponse(404,
        data: utf8.encode("404 Not Found"),
        headers: {"Content-Type": "text/plain"});
  };

  // ****************
  // * Internal Use *
  // ****************

  AutoreleasingCache storage = AutoreleasingCache();
  dynamic _serverSocket;

  HTTPServerInstance(this.host, this.port,
      {this.generalServeRoot, this.staticRoutes, this.securityContext});

  /// Causes the server to start listening for connections.
  ///
  /// If [securityContext] is not null, then it will use the [SecureServerSocket.bind] method. Otherwise, it will use [ServerSocket.bind].
  void start() async {
    if (securityContext != null) {
      _serverSocket = await SecureServerSocket.bind(host, port, securityContext,
          supportedProtocols: ["http/1.1"]);
      _serverSocket!.listen((socket) => _socketOnListen(socket));
      return;
    }
    _serverSocket = await ServerSocket.bind(host, port);
    _serverSocket!.listen((socket) => _socketOnListen(socket));
  }

  void _socketOnListen(Socket connection) {
    connection.setOption(SocketOption.tcpNoDelay, true);
    connection.listen((data) => _conOnData(data, connection));
  }

  void _conOnData(Uint8List data, Socket sender) async {
    var req = RBWSRequest.from(data);
    if (req == null) {
      return;
    }

    var response = await processRequest(req);
    if (onResponse != null) {
      onResponse!(response);
    }
    sender.add(response.generate11WithData());
    await sender.flush(); // Make sure we don't start sending other data.
    sender.destroy();
    // I've been having issues where data isn't recieved by browsers until
    // the socket is destroyed. To be so for real, I have no idea if it's
    // supposed to be like that, but the existence of Connection: keep-alive
    // seems to point to the contrary. If someone has the answer, please let
    // me know!
  }

  /// Handles requests as they're recieved.
  ///
  /// If defined, [onRequest] is called before anything else.
  /// If the server is insecure and [referralToSecureServer] is defined, it will attempt to upgrade requests with the header Upgrade-Insecure-Requests.
  /// Static routes are matched, as defined in [staticRoutes].
  /// If a static route cannot be matched and [generalServeRoot] is defined, it will attempt to load a file matching the requested path, starting at [generalServeRoot].
  /// If [generalServeRoot] is not defined or it cannot be loaded using [AutoreleasingCache.grab], it will call and return [routeNotFound].
  Future<RBWSResponse> processRequest(RBWSRequest request) async {
    if (onRequest != null) {
      onRequest!(request);
    }

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
      RBWSResponse getStatic = await staticRoutes![key]!(request);
      if (debug) {
        getStatic.headers["x-dbg-route-type"] = "static";
      }
      return getStatic;
    }

    // Dynamically load from storage.
    if (generalServeRoot == null) {
      return routeNotFound(request);
    }

    Uint8List? loadAttempt = await storage.grab(
        "$generalServeRoot${request.path}",
        ifNotCachedClearAfter: Duration(days: 1));
    if (loadAttempt == null) {
      return routeNotFound(request);
    }
    return RBWSResponse(200, data: loadAttempt, headers: {
      "Content-Type": lookupMimeType(request.path) ?? "application/octet-stream"
    });
  }
}
