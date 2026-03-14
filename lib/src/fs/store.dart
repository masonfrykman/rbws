import 'dart:async';
import 'dart:typed_data';

/// An object that can load from the filesystem given a path.
mixin Store {
  /// Loads a file from the filesystem given a path, returning the data it contains.
  FutureOr<Uint8List?> load(String path);

  /// Removes any data stored that's associated with a path.
  void purge(String path);

  /// Removes all data stored.
  void purgeAll();

  /// Whether there's data being stored associated with a path.
  bool contains(String path);

  /// When a file will expire.
  ///
  /// If the returned value is after [DateTime.now], then it can reasonably be
  /// expected that [load] for [path] will return the same content as when it was last loaded.
  ///
  /// If the returned value is null, then the store is not holding data for [path].
  DateTime? expirationOf(String path);
}
