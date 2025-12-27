import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:rbws/rbws.dart';

import 'dart:io';

void main() async {
  RootedAutoreleasingStore store = RootedAutoreleasingStore(
      "${Directory.systemTemp.path}/rbws-test-webroot",
      defaultStorageDuration: Duration(days: 1));

  setUpAll(() {
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
  });

  group("store() / load()", () {
    test("Can load from a valid path", () async {
      final fromStore = await store.load("/public/index.html");
      final fromKnownPath = File(
              "${Directory.systemTemp.path}/rbws-test-webroot/public/index.html")
          .readAsBytesSync();

      expect(fromStore, isNotNull);
      expect(fromStore, equals(fromKnownPath));
    });

    test("Does not load from an invalid path", () async {
      expect(await store.load("/blahblahblah"), isNull,
          reason:
              "The path '/blahblahblah' does not exist, .load() should return null.");
    });

    test("Should store from filesystem", () async {
      final existLoad = await store.load("/public/index.html");
      expect(existLoad, isNotNull);

      final ct = File(
              "${Directory.systemTemp.path}/rbws-test-webroot/public/index.html")
          .readAsBytesSync();

      File("${Directory.systemTemp.path}/rbws-test-webroot/public/index.html")
          .deleteSync();

      final notExistLoad = await store.load("/public/index.html");
      File("${Directory.systemTemp.path}/rbws-test-webroot/public/index.html")
          .writeAsBytesSync(ct); // Restore file
      expect(notExistLoad, isNotNull,
          reason:
              ".load() should store files for the amount of time set as [defaultStorageDuration]");
    });

    test("Should store without filesystem", () async {
      final storeData = utf8.encode("hey!");
      final sPath = "/fake_path";

      final storeOp = store.store(sPath, storeData);
      expect(storeOp, isTrue);

      final load = await store.load(sPath);
      expect(load, equals(storeData));
    });
  });

  group("contains()", () {
    test("returns true for valid path", () {
      final loadFakePath = store.contains(
          "/fake_path"); // stored in "Should store without filesystem" test.
      expect(loadFakePath, isTrue);
    });

    test("returns false for invalid path", () {
      final loadNotExisting = store.contains("/this_doesnt_exist_in_any_way");
      expect(loadNotExisting, isFalse);
    });

    test("returns false for an existing but not loaded path", () async {
      final loadValidPathNotExisting =
          store.contains("/public/subpage/blah.html");
      expect(loadValidPathNotExisting, isFalse);
    });
  });
}
