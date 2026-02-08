import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'connection.dart';

class ConnectionManager {
  WeakReference<ConnectionDelegate>? delegate;

  Connection? _connection;
  RawSocket? _hold;

  Isolate? _connectionIsolate;
  ReceivePort? _port;
  SendPort? _portToConnection;

  ConnectionManager() {
    _port = ReceivePort()..listen(_receivedMessage);
  }

  /// Handles messages recieved on [_port]
  void _receivedMessage(dynamic message) {
    if (message is SendPort) {
      print("Caught SendPort in mgr, sending the RawSocket");
      _portToConnection ??= message;
      //_portToConnection!.send(_hold);
      //_hold = null;
    } else if (message is Uint8List) {
      delegate?.target?._connectionReceivedMessage(this, message);
    }
  }

  void start(RawSocket socket) async {
    if (_connection != null) return;
    _hold = socket;
    print("Mgr.start");
    _port ??= ReceivePort()..listen(_receivedMessage);

    _connectionIsolate = await Isolate.spawn((sp) {
      print("Isolate spawned, $sp");
      Connection cn = Connection(socket);
      cn.startIsolated(sp);
    }, _port!.sendPort);
  }

  void sendMessage(Uint8List message) {
    _portToConnection?.send(message);
  }
}

mixin ConnectionDelegate {
  void _connectionReceivedMessage(ConnectionManager sender, Uint8List data);
}
