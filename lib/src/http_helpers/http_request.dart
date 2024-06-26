import 'dart:convert';
import 'dart:typed_data';

/// Container for a processed HTTP request.
class RBWSRequest {
  // (this is basically a constant. not officially.)
  // ignore: non_constant_identifier_names
  static final int _NEWLINE = utf8.encode("\n").first;

  /// The HTTP version. Most likely will be "1.1".
  String get version => _version;
  late String _version;

  /// The requested path. Always starts with a "/".
  String get path => _path;
  late String _path;

  /// HTTP method used.
  RBWSMethod get method => _method;
  late RBWSMethod _method;

  /// HTTP headers included in the request. If the request includes duplicate header keys, it will default to only storing the first.
  Map<String, String> get headers => _headers;
  late Map<String, String> _headers;

  /// The request's body.
  Uint8List? get data => _data;
  Uint8List? _data;

  RBWSRequest(RBWSMethod method, String path, String version,
      {Uint8List? data, Map<String, String>? headers}) {
    _data = data;
    _headers = headers ?? {};
    _method = method;
    _path = path;
    _version = version;
  }

  RBWSRequest.dataFromString(RBWSMethod method, String path, String version,
      {Map<String, String>? headers, String? data}) {
    _method = method;
    _path = path;
    _version = version;
    if (data != null) {
      _data = utf8.encode(data);
    }
    _headers = headers ?? {};
  }

  /// Parses a request from raw data.
  ///
  /// If it cannot discern a valid request, it returns null.
  static RBWSRequest? from(Uint8List data) {
    // First line: Contains version, path, and method.
    int firstNewline = data.indexWhere((x) => x == _NEWLINE);
    String firstLine = utf8.decode(data.sublist(0, firstNewline));
    if (firstLine.split(" ").length != 3) {
      return null; // Could be a problem with space encoding. whatever pitch it.
    }

    List<String> tokenizedFL = firstLine.split(" ");

    RBWSMethod method = RBWSMethod.fromString(tokenizedFL.first);
    if (method == RBWSMethod.unrecognized) {
      return null;
    }
    String path = tokenizedFL[1];
    String version = tokenizedFL[2].split("/").last;

    // Headers
    List<Uint8List> headerData = [];
    int beginIndex = firstNewline + 1;
    for (int i = firstNewline + 1; i < data.length; i++) {
      if (data[i] == _NEWLINE &&
          i + 1 != data.length &&
          data[i + 1] != _NEWLINE) {
        headerData.add(data.sublist(beginIndex, i));
        beginIndex = i + 1;
        continue;
      } else if (data[i] == _NEWLINE &&
          i + 1 != data.length &&
          data[i + 1] == _NEWLINE) {
        headerData.add(data.sublist(beginIndex, i));
        break;
      }
    }

    List<String> stringifiedHeaders = [];
    for (Uint8List header in headerData) {
      stringifiedHeaders.add(utf8.decode(header));
    }

    Map<String, String> headers = processHeaders(stringifiedHeaders);

    // Data (if exists.)

    Uint8List? reqData;
    if (headers.containsKey("Content-Length")) {
      int? len = int.tryParse(headers["Content-Length"]!);
      if (len != null) {
        reqData = data.sublist(data.length - len);
      }
    }

    return RBWSRequest(method, path, version, headers: headers, data: reqData);
  }

  // Splits HTTP headers using format <key>: <value> into a map.
  static Map<String, String> processHeaders(Iterable<String> list) {
    Map<String, String> s = {};
    for (String str in list) {
      int colon = str.indexOf(":");
      if (colon == -1 || s.containsKey(str.substring(0, colon))) {
        continue;
      }
      s[str.substring(0, colon)] = str.substring(colon + 2);
    }

    return s;
  }
}

/// HTTP methods
enum RBWSMethod {
  get,
  post,
  put,
  delete,
  head,
  unrecognized;

  @override
  String toString() {
    return super.toString().split(".").last.toUpperCase();
  }

  static RBWSMethod fromString(String container) {
    container = container.trim().toLowerCase();

    switch (container) {
      case "get":
        return get;
      case "post":
        return post;
      case "put":
        return put;
      case "delete":
        return delete;
      case "head":
        return head;
    }

    return unrecognized;
  }
}
