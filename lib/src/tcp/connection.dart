import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

class Connection {
  RawSocket? socket;

  Connection(this.socket);

  List<int> writeBuffer = [];

  void _socketEvent(RawSocketEvent event) {
    if (socket == null) return;
    print(event);

    switch (event) {
      case RawSocketEvent.write:
        int written = socket!.write(writeBuffer);
        writeBuffer.removeRange(0, written);
        if (writeBuffer.isNotEmpty) {
          socket!.writeEventsEnabled = true;
        }
        break;
      case RawSocketEvent.read:
        List<int> readBuffer = [];
        while (socket!.available() > 0) {
          List<int> read = socket!.read() ?? [];
          readBuffer.addAll(read);
        }

        if (readBuffer.isNotEmpty) {
          _receivedMessage(Uint8List.fromList(readBuffer));
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

  void _receivedMessage(Uint8List msg) {
    _outward?.send(msg);
  }

  void _write(List<int> msg) {
    if (socket == null) return;

    writeBuffer.addAll(msg);
    if (!socket!.writeEventsEnabled) {
      socket!.writeEventsEnabled = true;
    }
  }

  void startIsolated(SendPort outward) {
    if (_outward != null) return; // Prevent double start

    print("Cn.startIsolated");
    _outward = outward;
    outward.send(_inward.sendPort); // Give our send port to the outside.

    _inwardListener = _inward.listen((message) {
      print("Cn.msg: $message");
      if (message is List<int>) {
        print("receieved message");
        _write(message);
      } else if (message is RawSocket) {
        print("Receieved RawSocket");
        socket ??= message
          ..listen(_socketEvent)
          ..readEventsEnabled = true;
      }
    });
  }

  void stop() async {
    _inwardListener?.cancel();
    _inward.close();
  }
}
