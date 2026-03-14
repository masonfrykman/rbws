import 'dart:typed_data';

import 'autorelease_store.dart';
import '../util/rooted.dart';

/// Loads and stores files from the filesystem restricted to a certain directory.
/// After a specified [defaultStorageDuration], the data associated with a path is purged.
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
    return super.load(
      prefixed(path),
      ifNotCachedClearAfter: ifNotCachedClearAfter,
    );
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

  @override
  void setNewExpiration(String forPath, {Duration? newClearAfterDuration}) {
    super.setNewExpiration(
      prefixed(forPath),
      newClearAfterDuration: newClearAfterDuration,
    );
  }

  @override
  DateTime? expirationOf(String path) {
    return super.expirationOf(prefixed(path));
  }
}
