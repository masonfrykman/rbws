import 'package:test/test.dart';
import 'package:archive/archive.dart';
import 'dart:io';

import 'package:rbws/rbws.dart';

void main() {
  late HTTPServerInstance instance;
  late Socket client;

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
    instance = HTTPServerInstance('localhost', 45679,
        generalServeRoot: "${Directory.systemTemp.path}/rbws-test-webroot");
    instance.staticRoutes = {
      (RBWSMethod.get, "/testing"): (request) {
        return RBWSResponse.dataFromString(200, "123");
      }
    };

    client = await Socket.connect("localhost", 45679);
  });

  tearDown(() {
    instance.stop();
    client.close();
  });

  test('Respond with a static route', () {
    client.write("""GET /testing HTTP/1.1
    This: Doesnt
    Really: Matter


    """);
  });
}
