/// HTTP methods
enum RBWSMethod {
  get,
  post,
  put,
  delete,
  head;

  @override
  String toString() {
    return super.toString().split(".").last.toUpperCase();
  }

  /// Deduces the HTTP method represented in the argument.
  ///
  /// If it cannot deduce the method, it will return [RBWSMethod.unrecognized].
  static RBWSMethod fromString(String container) {
    container = container.trim().toLowerCase();

    switch (container) {
      case "get":
        return get;
      case "post":
        return post;
      case "put":
        return put;
      case "delete":
        return delete;
      case "head":
        return head;
    }

    throw FormatException(
        "Could not parse valid HTTP method from string.", container);
  }
}
