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

  dynamic host;
  int port;
  String? generalServeRoot;

  /// Routes matched from requested path and method.
  Map<(RBWSMethod, String), FutureOr<RBWSResponse> Function(RBWSRequest)>?
      staticRoutes;

  /// Security context used by [SecureServerSocket] to provide TLS support. Defining this will cause the server to be secure and to bind using [SecureServerSocket.bind]. If not defined, [ServerSocket.bind] will be used during [start] and all connections will be insecure.
  /// 
  /// It's STRONGLY RECOMMENDED that-if this server is public-facing-to spin up another [HTTPServerInstance] without a security context and to define [referralToSecureServer] so that connections can be upgraded from insecure to secure automatically.
  SecurityContext? securityContext;

  /// Used by insecure servers (see [securityContext]) to redirect clients sending requests with the "Upgrade-Insecure-Requests: 1" header to a secure server.
  String? referralToSecureServer;

  /// First call from [processRequest] when a request is recieved. This may not be called if [processRequest] is overriden.
  void Function(RBWSRequest)? onRequest;

  /// First call when a response is returned from [processRequest].
  void Function(RBWSResponse)? onResponse;

  /// Fallback handler for when every control flow path (static routes, loading files from filesystem, etc.) in [processRequest] fails.
  FutureOr<RBWSResponse> Function(RBWSRequest) routeNotFound = (r) {
    return RBWSResponse(404,
        data: utf8.encode("404 Not Found"),
        headers: {"Content-Type": "text/plain"}, toRequest: r);
  };

  // ****************
  // * Internal Use *
  // ****************

  /// Cache used by the server for files loaded from filesystem.
  AutoreleasingCache storage = AutoreleasingCache();
  dynamic _serverSocket;

  HTTPServerInstance(this.host, this.port,
      {this.generalServeRoot,
      this.staticRoutes,
      this.securityContext,
      this.onRequest,
      this.onResponse});

  /// Causes the server to start listening for connections.
  ///
  /// If [securityContext] is not null, then it will use the [SecureServerSocket.bind] method. Otherwise, it will use [ServerSocket.bind].
  void start() async {
    if (securityContext != null) {
        _serverSocket = await SecureServerSocket.bind(host, port, securityContext,
            supportedProtocols: ["http/1.1"]);

        _serverSocket!.handleError((err) {
          stderr.write("Secure server encountered an error!\n");
          if(err is HandshakeException) {
            stderr.write("\tThere was a problem with the TLS handshake.\n");
            stderr.write("\t${err.message}\n");
          } else if(err is Error) {
            stderr.write("\tUnrecognized error:\n");
            stderr.write("\t${err.stackTrace}\n");
          }
        }).listen((socket) => _socketOnListen(socket));
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
  /// 
  /// If the server is insecure and [referralToSecureServer] is defined, it will attempt to upgrade requests with the header Upgrade-Insecure-Requests.
  /// 
  /// Static routes are matched as defined in [staticRoutes].
  /// 
  /// If a static route cannot be matched and [generalServeRoot] is defined, it will attempt to load a file matching the requested path, starting at [generalServeRoot].
  /// 
  /// If [generalServeRoot] is not defined or it cannot be loaded using [AutoreleasingCache.grab], it will call and return [routeNotFound].
  Future<RBWSResponse> processRequest(RBWSRequest request) async {
    if (onRequest != null) {
      onRequest!(request);
    }

    // Upgrade-Insecure-Requests
    if (securityContext == null &&
        request.headers["Upgrade-Insecure-Requests"]?.trim() == "1" &&
        referralToSecureServer != null) {
      return RBWSResponse(303,
          headers: {
            "Vary": "Upgrade-Insecure-Requests",
            "Location": "$referralToSecureServer${request.path}"
          },
          toRequest: request);
    }

    // Check static routes
    var key = (request.method, request.path);
    if (staticRoutes != null && staticRoutes!.containsKey(key)) {
      RBWSResponse getStatic = await staticRoutes![key]!(request);
      getStatic.toRequest = request;
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
    return RBWSResponse(200,
        data: loadAttempt,
        headers: {
          "Content-Type":
              lookupMimeType(request.path) ?? "application/octet-stream"
        },
        toRequest: request);
  }
}
