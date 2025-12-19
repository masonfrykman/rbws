import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'filesystem_storable.dart';

/// Loads from the filesystem with no restriction and no storing.
///
/// The simplest implementation of [FilesystemStorable] that could exist.
class NoneStore with FilesystemStorable {
  @override
  FutureOr<Uint8List?> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  }

  /// Does nothing.
  @override
  void purge(String path) {}

  /// Does nothing.
  @override
  void purgeAll() {}

  /// Whether a file at the given path exists in the filesystem.
  @override
  bool contains(String path) {
    return File(path).existsSync();
  }
}
