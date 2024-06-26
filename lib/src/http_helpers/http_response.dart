import 'dart:convert';
import 'dart:typed_data';

import 'http_request.dart';

/// Container for a generated response.
class RBWSResponse {
  /// The request that the response was generated for.
  RBWSRequest? toRequest;

  /// List of headers defined by the application for EVERY response generated. Use lightly.
  static Map<String, String> appDefaultHeaders = {};

  /// HTTP status code of the response (ex. 200 OK, 404 Not Found)
  int status;

  final Map<String, String> _headers = {};

  Map<String, String> get headers {
    var x = appDefaultHeaders;
    x.addAll(_headers);
    if (data != null) {
      x["Content-Length"] = data!.length.toString();
    }
    if (!x.containsKey("Server")) {
      x["Server"] = "rbws";
    }
    return x;
  }

  set headers(Map<String, String> val) => _headers.addAll(val);

  /// Clears USER-DEFINED headers, will keep [appDefaultHeaders] intact.
  void clearHeaders() => _headers.clear();

  /// Removes a USER-DEFINED header.
  void removeHeader(String key) => _headers.remove(key);

  /// Body of the response.
  Uint8List? data;

  RBWSResponse(this.status,
      {this.data, Map<String, String>? headers, this.toRequest}) {
    if (headers != null) {
      this.headers = headers;
    }
  }

  /// Same as the default no-name constructor but takes the body in as a String instead of as a Uint8List.
  ///
  /// This is just a conveinience constructor as it immediately encodes [data] to a [Uint8List].
  RBWSResponse.dataFromString(this.status, String data,
      {this.toRequest, Map<String, String>? headers}) {
    if (headers != null) {
      this.headers = headers;
    }

    this.data = utf8.encode(data);
  }

  /// Generates the response headers as raw [Uint8List] without the [data]. The 11 stands for the HTTP version "HTTP/1.1" as successive versions do things differently.
  Uint8List generate11() {
    List<int> responseData = [];

    // 1st line
    responseData.addAll(utf8.encode("HTTP/1.1 ${statusToString(status)}\n"));

    // Headers
    for (MapEntry<String, String> header in headers.entries) {
      responseData.addAll(utf8.encode("${header.key}: ${header.value}\n"));
    }

    responseData.add(utf8.encode("\n").first);

    return Uint8List.fromList(responseData);
  }

  /// Same as [generate11] but includes the [data]. See [generate11] for more info.
  Uint8List generate11WithData() {
    Uint8List gen11 = generate11();

    if (data == null) {
      return gen11;
    }

    Uint8List combined = Uint8List(gen11.length + data!.length);
    for (int i = 0; i < gen11.length; i++) {
      combined[i] = gen11[i];
    }
    for (int i = gen11.length; i < combined.length; i++) {
      combined[i] = data![i - gen11.length];
    }
    return combined;
  }

  /// Returns the status code's corresponding description for use in HTTP/1.1 responses. (ex. 200 (int) -> 200 OK (String))
  static String statusToString(int status) {
    switch (status) {
      case 100:
        return "100 Continue";
      case 101:
        return "101 Switching Protocols";

      case 200:
        return "200 OK";
      case 201:
        return "201 Created";
      case 202:
        return "202 Accepted";
      case 203:
        return "203 Non-Authoritative Information";
      case 204:
        return "204 No Content";
      case 205:
        return "205 Reset Content";
      case 206:
        return "206 Partial Content";

      case 300:
        return "300 Multiple Choices";
      case 301:
        return "301 Moved Permanently";
      case 302:
        return "302 Found";
      case 303:
        return "303 See Other";
      case 304:
        return "304 Not Found";
      case 305:
        return "305 Use Proxy";
      case 307:
        return "307 Temporary Redirect";
      case 308:
        return "308 Permanent Redirect";

      case 400:
        return "400 Bad Request";
      case 401:
        return "401 Unauthorized";
      case 402:
        return "402 Payment Required";
      case 403:
        return "403 Forbidden";
      case 404:
        return "404 Not Found";
      case 405:
        return "405 Method Not Allowed";
      case 406:
        return "406 Not Acceptable";
      case 407:
        return "407 Proxy Authentication Required";
      case 408:
        return "408 Request Timeout";
      case 409:
        return "409 Conflict";
      case 410:
        return "410 Gone";
      case 411:
        return "411 Length Required";
      case 412:
        return "412 Precondition Failed";
      case 413:
        return "413 Content Too Large";
      case 414:
        return "414 URI Too Long";
      case 415:
        return "415 Unsupported Media Type";
      case 416:
        return "416 Range Not Satisfiable";
      case 417:
        return "417 Expectation Failed";
      case 418:
        return "418 I'm a teapot";
      case 421:
        return "421 Misdirected Request";
      case 422:
        return "422 Unprocessable Content";
      case 426:
        return "426 Upgrade Required";

      case 500:
        return "500 Internal Server Error";
      case 501:
        return "501 Not Implemented";
      case 502:
        return "502 Bad Gateway";
      case 503:
        return "503 Service Unavailable";
      case 504:
        return "504 Gateway Timeout";
      case 505:
        return "505 HTTP Version Not Supported";
    }
    return "$status";
  }
}
