import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

class Connection {
  final RawSocket _socket;

  Connection(this._socket);

  List<int> writeBuffer = [];

  void _socketEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.write:
        int written = _socket.write(writeBuffer);
        writeBuffer.removeRange(0, written);
        if (writeBuffer.isNotEmpty) {
          _socket.writeEventsEnabled = true;
        }
        break;
      case RawSocketEvent.read:
        List<int> readBuffer = [];
        while (_socket.available() > 0) {
          List<int> read = _socket.read() ?? [];
          readBuffer.addAll(read);
        }

        if (readBuffer.isNotEmpty) {
          _recievedMessage(Uint8List.fromList(readBuffer));
        }
        break;
      case RawSocketEvent.readClosed:
      case RawSocketEvent.closed:
        stop();
    }
  }

  SendPort? _outward;
  final ReceivePort _inward = ReceivePort();
  StreamSubscription? _inwardListener;

  void _recievedMessage(Uint8List msg) {
    _outward?.send(msg);
  }

  void _write(List<int> msg) {
    writeBuffer.addAll(msg);
    if (!_socket.writeEventsEnabled) {
      _socket.writeEventsEnabled = true;
    }
  }

  void startIsolated(SendPort outward) {
    if (_outward != null) return; // Prevent double start

    _outward = outward;
    outward.send(_inward.sendPort); // Give our send port to the outside.

    _inwardListener = _inward.listen((message) {
      if (message is! List<int>) return;
      _write(message);
    });

    _socket.listen(_socketEvent);
  }

  void stop() async {
    _inwardListener?.cancel();
    _inward.close();
  }
}
