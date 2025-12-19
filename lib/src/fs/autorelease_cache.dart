import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import '../exceptions/path_dne.dart';
import 'filesystem_interface.dart';

/// Stores paths that correspond to data. Also, optionally, stores the data with a timer that will fire and clear said data.
///
/// This is the default way that [HTTPServerInstance] loads and stores files (you can find the object it uses at [HTTPServerInstance.storage]).
class AutoreleasingStore with FilesystemStorable {
  final Map<String, (Uint8List, Timer?)> _store = {};

  /// The amount of time a piece of data will be stored for if unspecified.
  Duration? defaultStorageDuration;

  AutoreleasingStore({this.defaultStorageDuration});

  /// Stores data with a path. Optionally, creates a timer that clears the data after [clearAfter].
  /// If [clearAfter] is null, the timer will be set to fire after [defaultStorageDuration].
  /// If [defaultStorageDuration] is null, no timer will be created and data will be stored until program termination or [purge] is called with [path].
  ///
  /// Will not replace data already associated with [path].
  ///
  /// Returns whether the data was stored.
  bool store(String path, Uint8List data, {Duration? clearAfter}) {
    if (_store.containsKey(path)) {
      return false;
    }

    clearAfter ??= defaultStorageDuration;

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

  /// Gets data associated with a path.
  ///
  /// If the data is already stored, the already-loaded data is returned.
  /// If not, the data will be stored from the filesystem,
  ///   automatically clearing after the duration set in [ifNotCachedClearAfter].
  /// If the data cannot be loaded from the filesystem, returns null.
  ///
  /// Returns [Uint8List] containing the data or null if it cannot load the data.
  ///
  /// See documentation on [store] for how long the data is stored based on [ifNotCachedClearAfter] and [defaultStorageDuration]
  ///
  /// (Note: in API <= 2.0.1, this method was named 'grab')
  @override
  Future<Uint8List?> load(String path,
      {Duration? ifNotCachedClearAfter}) async {
    // If the cache already contains the data, return it.
    if (_store.containsKey(path)) {
      return _store[path]!.$1;
    }

    // If not, then load the data and store it.
    final fileHandle = File(path);
    if (!await fileHandle.exists()) {
      return null;
    }

    final data = await fileHandle.readAsBytes();
    final storeOperation = store(path, data, clearAfter: ifNotCachedClearAfter);
    if (!storeOperation) {
      return null;
    }

    return data;
  }

  /// Removes data associated with [path] from the store, cancelling the timer associated with it if existing.
  @override
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
  ///
  /// (Note: in API <= 2.0.1, this method was named 'clear')
  @override
  void purgeAll() {
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
  @override
  bool contains(String path) => _store.containsKey(path);

  /// Restarts the internal expiration timer for a given path with a new duration.
  ///
  /// The old timer is canceled.
  ///
  /// If the new duration is null, the data will be held indefinitely.
  ///
  /// Throws [PathDoesNotExistException] if [forPath] does not have data associated with it.
  void setNewExpiration(String forPath, {Duration? newClearAfterDuration}) {
    if (!_store.containsKey(forPath)) {
      throw PathDoesNotExistException(forPath);
    }

    var data = _store[forPath]!.$1;
    purge(forPath);
    store(forPath, data, clearAfter: newClearAfterDuration);
  }
}
