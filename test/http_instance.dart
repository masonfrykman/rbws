import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:rbws/rbws.dart';
import 'package:test/test.dart';

import 'dart:io';

void main() {
  late HTTPServerInstance instance;

  print("Setting up test web root");

  if (!File("test/resource/webroot.zip").existsSync()) {
    stderr.write(
        "Failed to find webroot.zip. Make sure you're running from the project root directory.");
    exit(2);
  }

  var zipBytes = File("test/resource/webroot.zip").readAsBytesSync();
  var zip = ZipDecoder().decodeBytes(zipBytes, verify: true);
  Directory("${Directory.systemTemp.path}/rbws-test-webroot").createSync();

  for (var file in zip) {
    if (file.isFile) {
      File("${Directory.systemTemp.path}/rbws-test-webroot/${file.name}")
          .writeAsBytesSync(file.content, flush: true);
    } else {
      Directory("${Directory.systemTemp.path}/rbws-test-webroot/${file.name}")
          .createSync(recursive: true);
    }
  }

  setUp(() async {
    instance = HTTPServerInstance("127.0.0.1", 45619);
    instance.storage = RootedAutoreleasingStore(
        "${Directory.systemTemp.path}/rbws-test-webroot/public");
    instance.staticRoutes = {
      (RBWSMethod.get, "/test"): (req) => RBWSResponse.dataFromString(
          200, "test data",
          toRequest: req, headers: {"Content-Type": "text/plain"}),
      (RBWSMethod.post, "/test"): (req) =>
          RBWSResponse.dataFromString(200, "test post"),
      (RBWSMethod.delete, "/test"): (req) =>
          RBWSResponse.dataFromString(200, "test delete"),
      (RBWSMethod.put, "/test"): (req) =>
          RBWSResponse.dataFromString(200, "test put")
    };
  });

  tearDown(() async {
    instance.stop(); // This does nothing if not listening.
  });

  test('tryToMatchStaticRoute()', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.get, "/test", "1.1");
    var response = await instance.tryToMatchStaticRoute(request);
    expect(response, isNot(equals(null)));
    expect(response!.status, equals(200));
    expect(response.data, equals(utf8.encode("test data")));
  });

  test('processGETRequest can get a static route', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.get, "/test", "1.1");
    var response = await instance.processGETRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test data")));
  });

  test('processPOSTRequest static route', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.post, "/test", "1.1");
    var response = await instance.processPOSTRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test post")));
  });

  test('processDELETERequest static route', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.delete, "/test", "1.1");
    var response = await instance.processDELETERequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test delete")));
  });

  test('processPUTRequest static route', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.put, "/test", "1.1");
    var response = await instance.processPUTRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test put")));
  });

  test('processRequest can match GET', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.get, "/test", "1.1");
    var response = await instance.processRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test data")));
  });

  test('processRequest can match POST', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.post, "/test", "1.1");
    var response = await instance.processRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test post")));
  });

  test('processRequest can match DELETE', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.delete, "/test", "1.1");
    var response = await instance.processRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test delete")));
  });

  test('processRequest can match PUT', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.put, "/test", "1.1");
    var response = await instance.processRequest(request);
    expect(response.status, equals(200));
    expect(response.data, equals(utf8.encode("test put")));
  });

  test('processRequest can generate HEAD', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.head, "/test", "1.1");
    var response = await instance.processRequest(request);
    expect(response.status, equals(200));
    expect(response.headers["Content-Length"],
        equals("test data".length.toString()));
    expect(response.data, equals(null));
  });

  test('Server can do auto loading from path.', () async {
    RBWSRequest request =
        RBWSRequest.dataFromString(RBWSMethod.get, "/index.html", "1.1");
    RBWSRequest request2 =
        RBWSRequest.dataFromString(RBWSMethod.get, "/subpage/blah.html", "1.1");
    var response = await instance.processRequest(request);
    var response2 = await instance.processRequest(request2);

    expect(response.status, equals(200));
    expect(response2.status, equals(200));
    expect(utf8.decode(response.data ?? []), startsWith("<!DOCTYPE html>"));
    expect(utf8.decode(response2.data ?? []), startsWith("<!DOCTYPE html>"));
  });
}
