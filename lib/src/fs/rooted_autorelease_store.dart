import 'dart:typed_data';

import 'autorelease_store.dart';
import '../util/rooted.dart';

/// Loads and stores files from the filesystem restricted to a certain directory.
class RootedAutoreleasingStore extends AutoreleasingStore with Rooted {
  String _rootPrefix;

  /// The prefix being used. Cannot be changed after construction.
  @override
  String get root => _rootPrefix;

  RootedAutoreleasingStore(this._rootPrefix, {super.defaultStorageDuration}) {
    if (_rootPrefix.endsWith("/")) {
      // remove the last /
      _rootPrefix = _rootPrefix.substring(0, _rootPrefix.length - 1);
    }
  }

  @override
  Future<Uint8List?> load(String path, {Duration? ifNotCachedClearAfter}) {
    return super
        .load(prefixed(path), ifNotCachedClearAfter: ifNotCachedClearAfter);
  }

  @override
  bool store(String path, Uint8List data, {Duration? clearAfter}) {
    return super.store(prefixed(path), data, clearAfter: clearAfter);
  }

  @override
  bool contains(String path) {
    return super.contains(prefixed(path));
  }

  @override
  bool purge(String path) {
    return super.purge(prefixed(path));
  }
}
