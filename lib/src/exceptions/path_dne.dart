/// Thrown when attempting to perform an operation on a path in [AutoreleasingStore] that doesn't exist.
class PathDoesNotExistException implements Exception {
  /// The path that generated the exception
  String offendingPath;

  PathDoesNotExistException(this.offendingPath);

  @override
  String toString() =>
      "The path '$offendingPath' does not exist yet access was attempted.";
}
