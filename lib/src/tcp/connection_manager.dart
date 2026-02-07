import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'connection.dart';

class ConnectionManager {
  ConnectionDelegate? delegate;

  Connection? _connection;

  Isolate? _connectionIsolate;
  final ReceivePort _port = ReceivePort();
  SendPort? _portToConnection;

  ConnectionManager() {
    _port.listen(_receivedMessage);
  }

  /// Handles messages recieved on [_port]
  void _receivedMessage(dynamic message) {
    if (message is SendPort) {
      _portToConnection ??= message;
    } else if (message is Uint8List) {
      delegate?._connectionReceivedMessage(this, message);
    }
  }

  void start(RawSocket socket) async {
    if (_connection != null) return;

    _connection = Connection(socket);
    _connectionIsolate =
        await Isolate.spawn(_connection!.startIsolated, _port.sendPort);
  }

  void sendMessage(Uint8List message) {
    _portToConnection?.send(message);
  }
}

mixin ConnectionDelegate {
  void _connectionReceivedMessage(ConnectionManager sender, Uint8List data);
}
