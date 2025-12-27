import 'dart:io';

import 'package:rbws/rbws.dart';
import 'package:test/test.dart';

import 'dart:convert';

void main() {
  late RBWSRequest specimin;

  group("Parsing", () {
    bool passedSetup = false;

    setUp(() {
      var data = utf8.encode(
          "GET /blah HTTP/1.1\r\nAccept: en-us\r\nContent-Encoding: utf8\r\nBadHeader:\r\nBing: Bong\r\n\r\nI am a payload.\r\n");

      var s = RBWSRequest.from(data);
      if (s == null) {
        stderr.writeln("Data parse failed! This section cannot be run.");
      } else {
        specimin = s;
        passedSetup = true;
      }
    });

    test("out a regular header", () {
      expect(specimin.headers["Content-Encoding"], "utf8", skip: !passedSetup);
    });
  });
}
