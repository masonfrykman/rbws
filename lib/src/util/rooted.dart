/// Provides a standard way of prefixing a root.
mixin Rooted {
  /// The root used for prefixing. Must be provided by the implementer.
  String get root;

  /// Cleans and prefixes a path with the [root]
  String prefixed(String path) {
    path = path.replaceAll("..", ""); // prevent escaping the root.
    if (path.startsWith(root)) return path; // Already prefixed
    if (!path.startsWith("/")) {
      path = "/$path";
    }
    return root + path;
  }
}
