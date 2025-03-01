/// Indicates that a function was illegally called while the server was already running.
class ServerRunningException {
  /// The name of the function that spawned the exception.
  String offender;

  ServerRunningException(this.offender);

  @override
  String toString() =>
      "Attempted call to '$offender' while server is running. (this is not allowed)";
}
