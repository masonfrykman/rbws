import 'dart:async';

import 'dart:typed_data';

import '../util/rooted.dart';

import 'none_store.dart';

/// Loads files from the filesystem with a defined starting point.
class RootedNoneStore extends NoneStore with Rooted {
  final String _rootPrefix;

  @override
  String get root => _rootPrefix;

  RootedNoneStore(this._rootPrefix);

  @override
  FutureOr<Uint8List?> load(String path) {
    return super.load(prefixed(path));
  }

  @override
  void purge(String path) {
    super.purge(prefixed(path));
  }

  @override
  bool contains(String path) {
    return super.contains(prefixed(path));
  }
}
