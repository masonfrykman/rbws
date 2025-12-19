import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';

import 'exceptions/server_running.dart';
import 'http_helpers/http_request.dart';
import 'http_helpers/http_response.dart';
import 'http_helpers/http_method.dart';
import 'fs/autorelease_cache.dart';
import 'fs/filesystem_interface.dart';

/// The main object that accepts connections, recieves requests, and generates / sends responses.
///
/// ### Request Call Pipeline
///
/// 1. [processRequest]
/// 2. [onRequest] (if defined)
/// 3. [shouldUpgradeInsecureRequest]
/// 4. [matchRequestToMethodProcessFunction]
/// 5. Goes to corresponding method function ex. [processGETRequest]
/// 6. [tryToMatchStaticRoute]
/// 7. If GET or HEAD and [generalServeRoot] is defined, will try to match the requested path to a file in [generalServeRoot] and load it through [AutoreleasingStore].
/// 8. [routeNotFound]
class HTTPServerInstance {
  // *************************
  // * General Configuration *
  // *************************

  dynamic _host;

  /// The internet address the server will bind to. See [ServerSocket.bind] for more information on what this value can be.
  dynamic get host => _host;

  /// Sets the host the server will bind to. Throws [ServerRunningException] if the server is running.
  set host(dynamic value) {
    if (_serverSocket != null) {
      throw ServerRunningException("HTTPServerInstance.host");
    }
    _host = value;
  }

  int _port;

  /// The port the server will bind to.
  int get port => _port;

  /// Sets the port the server will bind to. Throws [ServerRunningException] if the server is running.
  set port(int value) {
    if (_serverSocket != null) {
      throw ServerRunningException("HTTPServerInstance.port");
    }
    _port = value;
  }

  /// The root directory for where [processGETRequest] will attempt to load a file from the filesystem and cache it, using [storage].
  String? get generalServeRoot => _generalServeRoot;
  String? _generalServeRoot;

  /// Sets the general serve root. (see the getter for more information)
  set generalServeRoot(val) {
    if (val == null) {
      return;
    }
    _generalServeRoot = Directory(val).absolute.path;
  }

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
        headers: {"Content-Type": "text/plain"},
        toRequest: r);
  };

  // ****************
  // * Internal Use *
  // ****************

  /// Interface used by the server for loading data from the filesystem.
  FilesystemStorable storage = AutoreleasingStore();
  dynamic _serverSocket;

  HTTPServerInstance(this._host, this._port,
      {String? generalServeRoot,
      this.staticRoutes,
      this.securityContext,
      this.onRequest,
      this.onResponse}) {
    this.generalServeRoot =
        generalServeRoot; // Use the setter to fix Windows paths.
  }

  /// Causes the server to start listening for connections.
  ///
  /// If [securityContext] is not null, then it will use the [SecureServerSocket.bind] method. Otherwise, it will use [ServerSocket.bind].
  void start() async {
    if (securityContext != null) {
      // Secure server
      _serverSocket = await SecureServerSocket.bind(host, port, securityContext,
          supportedProtocols: ["http/1.1"])
        ..handleError((err) {
          stderr.write(
              "Secure server encountered (and, lucky you, is handling) an error!\n");
          if (err is HandshakeException) {
            stderr.writeln(
                "\tThere was a problem with the TLS handshake. This can usually be ignored, or there might be a problem with your SecurityContext configuration.");
            stderr
                .writeln("\tHandshakeException error message: ${err.message}");
          } else if (err is Error) {
            stderr.writeln("\tError type: '${err.runtimeType}'");
            stderr.writeln("\tStack Trace: ${err.stackTrace}");
          }
        }).listen((socket) => _socketOnListen(socket), cancelOnError: false);
      return;
    }

    // securityContext == null (Insecure server)
    _serverSocket = await ServerSocket.bind(host, port)
      ..handleError((err) {
        stderr.writeln("Server encountered an error!");
        stderr.writeln("\tError type: '${err.runtimeType}'");
        stderr.writeln("\tStack trace: ${err.runtimeType}");
      }).listen((socket) => _socketOnListen(socket), cancelOnError: false);
  }

  /// Stops accepting connections.
  void stop() async {
    if (_serverSocket != null) {
      await _serverSocket.close();
      _serverSocket = null;
    }
  }

  void _socketOnListen(Socket connection) {
    connection.setOption(SocketOption.tcpNoDelay, true);
    connection.listen((data) => _conOnData(data, connection),
        onError: (err, stack) {
      stderr.writeln(
          "HTTPServerInstance encountered an error while listening for connections!");
      stderr.writeln(
          "\tThis is being \"handled\" to prevent crashing, here's the error information so you can investigate:");
      stderr.writeln("\terr: $err");
      stderr.writeln("\tstack trace: $stack");
    });
  }

  void _conOnData(Uint8List data, Socket sender) async {
    RBWSRequest? req;
    try {
      req = RBWSRequest.from(data);
    } on FormatException {
      var response = RBWSResponse.dataFromString(400, "400 Bad Request");
      sender.add(response.generate11WithData());
      await sender.flush(); // Make sure we don't start sending other data.
      sender.destroy();
      return;
    }
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
  /// Branches off into method-specific functions (ex. GET -> [processGETRequest]).
  /// If the method is HEAD, it will call [processGETRequest] for the path and return the response but stripped of data.
  FutureOr<RBWSResponse> processRequest(RBWSRequest request) {
    if (onRequest != null) {
      onRequest!(request);
    }

    // Upgrade-Insecure-Requests
    var shouldUpgrade = shouldUpgradeInsecureRequest(request);
    if (shouldUpgrade != null) {
      return shouldUpgrade;
    }

    return matchRequestToMethodProcessFunction(request);
  }

  /// Determines whether a request should be upgraded via Upgrade-Insecure-Requests.
  ///
  /// If true, returns the upgrade response.
  /// If false, returns null.
  RBWSResponse? shouldUpgradeInsecureRequest(RBWSRequest request) {
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
    return null;
  }

  /// Calls the request processing function based on the request's method.
  ///
  /// Supports GET, HEAD, POST, PUT, DELETE. Other methods will cause a 405 Method Not Allowed response.
  ///
  /// For example, a request with a GET method will call [HTTPServerInstance.processGETRequest]
  ///
  /// A request with the HEAD method will call [HTTPServerInstance.processGETRequest] but will omit the body.
  FutureOr<RBWSResponse> matchRequestToMethodProcessFunction(
      RBWSRequest request) {
    switch (request.method) {
      case RBWSMethod.get:
        return processGETRequest(request);
      case RBWSMethod.post:
        return processPOSTRequest(request);
      case RBWSMethod.put:
        return processPUTRequest(request);
      case RBWSMethod.delete:
        return processDELETERequest(request);
      case RBWSMethod.head:
        var repHead = RBWSRequest(RBWSMethod.get, request.path, "1.1",
            headers: request.headers, data: request.data);
        var response = processGETRequest(repHead).then((response) {
          // The content-type header gets dynamically added on when the getter
          // is accessed. So, we have to save it.
          var ct = response.headers["Content-Type"] ?? "0";
          response.data = null;
          response.headers["Content-Type"] = ct;
          return response;
        });
        return response;
    }
  }

  /// Processes GET requests handled by [processRequest].
  ///
  /// It will first attempt to match a static route, then, if unsuccessful, will attempt to load a file using [storage].
  Future<RBWSResponse> processGETRequest(RBWSRequest request) async {
    // Check static routes
    RBWSResponse? match = await tryToMatchStaticRoute(request);
    if (match != null) {
      return match;
    }

    // Dynamically load from storage.
    if (generalServeRoot == null) {
      return routeNotFound(request);
    }

    Uint8List? loadAttempt =
        await storage.load("$generalServeRoot${request.path}");
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

  Future<RBWSResponse> _defaultStaticRouteMatch(RBWSRequest request) async {
    RBWSResponse? match = await tryToMatchStaticRoute(request);
    if (match != null) {
      return match;
    }
    return routeNotFound(request);
  }

  /// Processes POST requests handled by [processRequest]
  Future<RBWSResponse> processPOSTRequest(RBWSRequest request) async =>
      await _defaultStaticRouteMatch(request);

  /// Processes PUT requests handled by [processRequest]
  Future<RBWSResponse> processPUTRequest(RBWSRequest request) async =>
      await _defaultStaticRouteMatch(request);

  /// Processes DELETE requests handled by [processRequest]
  Future<RBWSResponse> processDELETERequest(RBWSRequest request) async =>
      await _defaultStaticRouteMatch(request);

  /// Attempts to find a static route in [staticRoutes] that matches the [request] method and path.
  /// If successful, it will call the handler and return the response.
  Future<RBWSResponse?> tryToMatchStaticRoute(RBWSRequest request) async {
    var key = (request.method, request.path);
    if (staticRoutes != null && staticRoutes!.containsKey(key)) {
      RBWSResponse getStatic = await staticRoutes![key]!(request);
      getStatic.toRequest = request;
      return getStatic;
    }
    return null;
  }
}
