import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'store.dart';

/// Loads from the filesystem with no restriction and no storing.
///
/// The simplest implementation of [Store] that could exist.
class NoneStore with Store {
  @override
  FutureOr<Uint8List?> load(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  }

  /// Does nothing, only defined to conform to [Store].
  @override
  void purge(String path) {}

  /// Does nothing, only defined to conform to [Store].
  @override
  void purgeAll() {}

  /// Whether a file at the given path exists in the filesystem.
  @override
  bool contains(String path) {
    return File(path).existsSync();
  }

  @override
  DateTime? expirationOf(String path) => null; // This store doesn't hold data.
}
