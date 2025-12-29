/// Provides a standard way of prefixing a root.
mixin Rooted {
  /// The root used for prefixing.
  String get root;

  /// Cleans and prefixes a path with the [root]
  String prefixed(String path) {
    path = path.replaceAll("..", ""); // prevent escaping the root.
    if (!path.startsWith("/")) {
      path = "/$path";
    }
    if (path.startsWith(root)) return path; // Already prefixed
    return root + path;
  }
}
