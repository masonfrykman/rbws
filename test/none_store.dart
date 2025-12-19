import 'dart:convert';
import 'dart:io';

import 'package:rbws/rbws.dart';
import 'package:test/test.dart';

void main() async {
  NoneStore store = NoneStore();
  final testData = utf8.encode("test!!!");
  final testHandle = File("${Directory.systemTemp.path}/rbws.ns.test");

  setUpAll(() {
    // Write the test data to the filesystem
    testHandle.writeAsBytesSync(testData);
  });

  tearDownAll(() {
    // Clean up test data.
    if (testHandle.existsSync()) {
      testHandle.deleteSync();
    }
  });

  setUp(() {
    store = NoneStore();
  });

  test("NoneStore can load from the filesystem", () async {
    expect(await store.load(testHandle.absolute.path), equals(testData));
  });

  test("NoneStore should not retain data.", () async {
    expect(await store.load(testHandle.absolute.path), equals(testData));
    testHandle.writeAsStringSync("Different data", flush: true);
    expect(await store.load(testHandle.absolute.path), isNot(equals(testData)));
  });

  test("NoneStore contains checks filesystem existence.", () {
    expect(store.contains(testHandle.absolute.path), equals(true));
    testHandle.deleteSync();
    expect(store.contains(testHandle.absolute.path), equals(false));
  });
}
