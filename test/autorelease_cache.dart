import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:rbws/rbws.dart';

void main() async {
  var testData = utf8.encode("Hello, World!");
  var testData2 = utf8.encode("Goodbye, World!");
  AutoreleasingStore? cache;

  setUp(() {
    cache = AutoreleasingStore();
  });

  tearDown(() {
    cache = null;
  });

  test('Data stores and is able to be gotten later', () async {
    expect(cache!.store("/reallycooldata", testData, clearAfter: null),
        equals(true));
    expect(await cache!.load("/reallycooldata"), equals(testData));
  });

  test('Data can be purged', () async {
    cache!.store("/reallycooldata", testData, clearAfter: null);
    expect(cache!.purge("/reallycooldata"), equals(true));
    expect(await cache!.load("/reallycooldata"), equals(null));
  });

  await File("${Directory.systemTemp.path}/rbws.test").writeAsBytes(testData);

  test('Data can be stored from disk', () async {
    expect(await cache!.load("${Directory.systemTemp.path}/rbws.test"),
        equals(testData));
  });

  test('contains', () {
    cache!.store("/contains-test", testData);
    expect(cache!.contains("/contains-test"), equals(true));
  });

  test('Store can be cleared', () async {
    for (int i = 0; i < 10; i++) {
      cache!.store("/$i", testData);
    }
    cache!.purgeAll();
    for (int i = 0; i < 10; i++) {
      expect(await cache!.load("/$i"), equals(null));
    }
  });

  group('[Exception]', () {
    test('setNewExpiration() throws PathDoesNotExistException', () {
      expect(() => cache!.setNewExpiration("/still-dne"),
          throwsA(isA<PathDoesNotExistException>()));
    });
  });

  group('[Time-based]', () {
    test('Data automatically clears out (takes at least 3 seconds)', () async {
      expect(
          cache!.store("/reallycooldata", testData,
              clearAfter: Duration(seconds: 1)),
          equals(true));
      var delayedCheck = await Future.delayed(Duration(seconds: 3), () {
        return cache!.load("/reallycooldata");
      });
      expect(delayedCheck, equals(null),
          reason:
              "The data should be cleared out after 1 second. We waited 3.");
    });

    test('Store can set new expiration timer. (takes at least 7 seconds)',
        () async {
      cache!.store("/expires", testData);
      expect(cache!.contains("/expires"), equals(true));

      cache!.setNewExpiration("/expires",
          newClearAfterDuration: Duration(seconds: 5));
      expect(
          cache!.contains("/expires"), equals(true)); // should still be there

      await Future.delayed(Duration(seconds: 7), () {
        expect(
            cache!.contains("/expires"), equals(false)); // shouldn't be there.
      });
    });
  });
}
