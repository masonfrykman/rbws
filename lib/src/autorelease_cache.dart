import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

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
}
