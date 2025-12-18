import 'dart:async';
import 'dart:typed_data';

mixin FilesystemStorable {
  /// Loads a file from the filesystem given a path, returning the data it contains.
  FutureOr<Uint8List?> load(String path);

  /// Removes any data stored that's associated with a path.
  void purge(String path);

  /// Removes all data stored.
  void purgeAll();

  /// Whether there's data being stored associated with a path.
  bool contains(String path);
}
