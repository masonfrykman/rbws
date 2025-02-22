class PathDoesNotExistException implements Exception {
  String offendingPath;

  PathDoesNotExistException(this.offendingPath);

  @override
  String toString() =>
      "The path '$offendingPath' does not exist yet access was attempted.";
}
