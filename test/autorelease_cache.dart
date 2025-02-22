import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:rbws/rbws.dart';

void main() async {
  var testData = utf8.encode("Hello, World!");
  AutoreleasingCache? cache;

  setUp(() {
    cache = AutoreleasingCache();
  });

  tearDown(() {
    cache = null;
  });

  test('Data stores and is able to be gotten later', () async {
    expect(cache!.store("/reallycooldata", testData, clearAfter: null),
        equals(true));
    expect(await cache!.grab("/reallycooldata"), equals(testData));
  });

  test('Data automatically clears out', () async {
    expect(
        cache!.store("/reallycooldata", testData,
            clearAfter: Duration(seconds: 1)),
        equals(true));
    var delayedCheck = await Future.delayed(Duration(seconds: 3), () {
      return cache!.grab("/reallycooldata");
    });
    expect(delayedCheck, equals(null),
        reason: "The data should be cleared out after 1 second. We waited 3.");
  });

  test('Data can be purged', () async {
    cache!.store("/reallycooldata", testData, clearAfter: null);
    expect(cache!.purge("/reallycooldata"), equals(true));
    expect(await cache!.grab("/reallycooldata"), equals(null));
  });

  await File("${Directory.systemTemp.path}/rbws.test").writeAsBytes(testData);

  test('Data can be stored from disk', () async {
    expect(await cache!.storeFromDisk("${Directory.systemTemp.path}/rbws.test"),
        equals(testData.length));
    expect(await cache!.grab("${Directory.systemTemp.path}/rbws.test"),
        equals(testData));
  });

  test('Data can be stored from disk with a false path', () async {
    expect(
        await cache!.storeFromDiskWithFalsePath(
            "${Directory.systemTemp.path}/rbws.test", "random"),
        equals(testData.length));
    expect(await cache!.grab("random"), equals(testData));
  });

  test('contains', () {
    cache!.store("/contains-test", testData);
    expect(cache!.contains("/contains-test"), equals(true));
  });

  test('Store can be cleared', () async {
    for (int i = 0; i < 10; i++) {
      cache!.store("/$i", testData);
    }
    cache!.clear();
    for (int i = 0; i < 10; i++) {
      expect(await cache!.grab("/$i", cacheIfNotAlready: false), equals(null));
    }
  });
}
