import 'dart:typed_data';

import 'autorelease_store.dart';

/// Loads and stores files from the filesystem restricted to a certain directory.
class RootedAutoreleasingStore extends AutoreleasingStore {
  String _rootPrefix;

  /// The prefix being used. Cannot be changed after construction.
  String get rootPrefix => _rootPrefix;

  RootedAutoreleasingStore(this._rootPrefix, {super.defaultStorageDuration}) {
    if (_rootPrefix.endsWith("/")) {
      // remove the last /
      _rootPrefix = _rootPrefix.substring(0, _rootPrefix.length - 1);
    }
  }

  String _prefixed(String path) {
    path = path.replaceAll("..", ""); // prevent escaping the root.
    if (!path.startsWith("/")) {
      path = "/$path";
    }
    return _rootPrefix + path;
  }

  @override
  Future<Uint8List?> load(String path, {Duration? ifNotCachedClearAfter}) {
    return super
        .load(_prefixed(path), ifNotCachedClearAfter: ifNotCachedClearAfter);
  }

  @override
  bool store(String path, Uint8List data, {Duration? clearAfter}) {
    return super.store(_prefixed(path), data, clearAfter: clearAfter);
  }

  @override
  bool contains(String path) {
    return super.contains(_prefixed(path));
  }

  @override
  bool purge(String path) {
    return super.purge(_prefixed(path));
  }
}
