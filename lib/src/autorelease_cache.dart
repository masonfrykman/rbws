import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'exceptions/path_dne.dart';

/// Stores paths that correspond to data. Also, optionally, stores the data with a timer that will fire and clear said data.
///
/// This is the default way that [HTTPServerInstance] loads and stores files (you can find the object it uses at [HTTPServerInstance.storage]).
class AutoreleasingCache {
  final Map<String, (Uint8List, Timer?)> _store = {};

  AutoreleasingCache();

  /// Stores data with a path. Optionally, creates a timer that clears the data after [clearAfter]; otherwise it will stay loaded until removed using [purge] or the program exits.
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

  /// Loads data from the disk using [path] as a literal filesystem path and as the symbolic path in the key store. See [store] for how [clearAfter] works.
  Future<int> storeFromDisk(String path, {Duration? clearAfter}) async {
    if (_store.containsKey(path)) {
      return -1;
    }
    if (!await File(path).exists() || !await FileSystemEntity.isFile(path)) {
      return 0;
    }

    Uint8List data = await File(path).readAsBytes();
    return store(File(path).absolute.path, data, clearAfter: clearAfter)
        ? data.length
        : 0;
  }

  /// Loads data same as [storeFromDisk] but substitutes the internal path with a false path.
  ///
  /// Basically, [path] is the filesystem path to the data and [falsePath] is the path used to store the data in the key store.
  Future<int> storeFromDiskWithFalsePath(String path, String falsePath,
      {Duration? clearAfter}) async {
    if (_store.containsKey(path)) {
      return -1;
    }
    if (!await File(path).exists() || !await FileSystemEntity.isFile(path)) {
      return 0;
    }

    Uint8List data = await File(path).readAsBytes();
    return store(falsePath, data, clearAfter: clearAfter) ? data.length : 0;
  }

  /// Gets cached data.
  ///
  /// If the data is not already cached and [cacheIfNotAlready] is true (default), it will attempt to load the data from disk using [storeFromDisk] and pass in [ifNotCachedClearAfter]. See [store] for further description of the timer's behavior.
  /// Otherwise, if [cacheIfNotAlready] is false or [storeFromDisk] fails, it will return null if not already stored.
  ///
  /// If the data is already stored or [storeFromDisk] succeeds, it will return the data as a [Uint8List].
  Future<Uint8List?> grab(String path,
      {bool cacheIfNotAlready = true, Duration? ifNotCachedClearAfter}) async {
    if (!_store.containsKey(path)) {
      if (!cacheIfNotAlready) {
        return null;
      }
      var storeAction =
          await storeFromDisk(path, clearAfter: ifNotCachedClearAfter);
      if (storeAction == 0) {
        return null;
      }
    }
    if (_store[path] != null) {
      return _store[path]!.$1;
    }
    return null;
  }

  /// Removes data from the store via it's corresponding path.
  ///
  /// If the timer set during [store] is running, it will be canceled.
  bool purge(String path) {
    (Uint8List, Timer?)? removal = _store.remove(path);
    if (removal == null) return false;

    if (removal.$2 != null) {
      removal.$2!.cancel();
    }

    return true;
  }

  /// Clears the store of all data.
  ///
  /// Cancels all timers before clearing.
  void clear() {
    // Iterate through and clear times
    for (var pair in _store.entries) {
      if (pair.value.$2 != null) {
        pair.value.$2!.cancel();
      }
    }

    // Now actually clear the store.
    _store.clear();
  }

  /// Whether the store has data at a corresponding path.
  bool contains(String path) => _store.containsKey(path);

  /// Restarts the internal expiration timer for a given path with a new duration.
  ///
  /// The old timer is canceled.
  ///
  /// If the new duration is null, the data will be held indefinitely.
  ///
  /// If [forPath] is not a path defined in the store, [PathDoesNotExistException] is thrown.
  void setNewExpiration(String forPath, {Duration? newClearAfterDuration}) {
    if (!_store.containsKey(forPath)) {
      throw PathDoesNotExistException(forPath);
    }

    var data = _store[forPath]!.$1;
    purge(forPath);
    store(forPath, data, clearAfter: newClearAfterDuration);
  }

  /// Replaces the data at [path] with [data].
  ///
  /// Returns the old data.
  ///
  /// If [newClearAfterDuration] is null, the data will never expire.
  ///
  /// If [path] does not exist, [PathDoesNotExistException] will be thrown.
  Uint8List replace(String path, Uint8List data,
      {Duration? newClearAfterDuration}) {
    if (!_store.containsKey(path)) {
      throw PathDoesNotExistException(path);
    }

    var data = _store[path]!.$1;
    purge(path);
    store(path, data, clearAfter: newClearAfterDuration);
    return data;
  }
}
