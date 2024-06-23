import 'dart:convert';
import 'dart:typed_data';

class RBWSRequest {
  // (this is basically a constant. not officially.)
  // ignore: non_constant_identifier_names
  static int NEWLINE = utf8.encode("\n").first;

  String version;
  String path;
  RBWSMethod method;

  Map<String, String> headers;
  Uint8List? data;

  RBWSRequest(this.method, this.path, this.version,
      {this.data, required this.headers});

  static RBWSRequest? from(Uint8List data) {
    // First line: Contains version, path, and method.
    int firstNewline = data.indexWhere((x) => x == NEWLINE);
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
      if (data[i] == NEWLINE &&
          i + 1 != data.length &&
          data[i + 1] != NEWLINE) {
        headerData.add(data.sublist(beginIndex, i));
        beginIndex = i + 1;
        continue;
      } else if (data[i] == NEWLINE &&
          i + 1 != data.length &&
          data[i + 1] == NEWLINE) {
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

enum RBWSMethod {
  get,
  post,
  put,
  delete,
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
    }

    return unrecognized;
  }
}
