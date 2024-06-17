import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

class AutoreleasingCache {
  final Map<String, (Uint8List, Timer?)> _store = {};

  AutoreleasingCache();

  bool store(String path, Uint8List data, {Duration? clearAfter}) {
    if (_store.containsKey(path)) {
      return false;
    }

    _store[path] = (
      data,
      clearAfter == null
          ? null
          : Timer(clearAfter, () {
              _store.remove(path);
            })
    );

    return true;
  }

  Future<int> storeFromDisk(String path, {Duration? clearAfter}) async {
    if (_store.containsKey(path)) {
      return -1;
    }
    if (await File(path).exists()) {
      return 0;
    }

    Uint8List data = await File(path).readAsBytes();
    return store(File(path).absolute.path, data, clearAfter: clearAfter)
        ? data.length
        : 0;
  }

  bool purge(String path) {
    (Uint8List, Timer?)? removal = _store.remove(path);
    if (removal == null) return false;

    if (removal.$2 != null) {
      removal.$2!.cancel();
    }

    return true;
  }
}
