import 'dart:async';
import 'dart:io';

import 'messages.dart';
import 'wsjtx_reader.dart';

/// Binds a UDP socket on [port] (default WSJT-X 2237) and emits a decoded
/// stream of [WsjtxMessage]s. Supports optional multicast group join.
class UdpListenerService {
  final int port;
  final String bindAddress;
  final String? multicastGroup;

  RawDatagramSocket? _socket;
  final _controller = StreamController<WsjtxMessage>.broadcast();
  DateTime? _lastPacket;

  UdpListenerService({
    this.port = 2237,
    this.bindAddress = '0.0.0.0',
    this.multicastGroup,
  });

  Stream<WsjtxMessage> get messages => _controller.stream;
  DateTime? get lastPacketAt => _lastPacket;
  bool get isBound => _socket != null;

  Future<void> start() async {
    await stop();
    final addr = InternetAddress(bindAddress);
    // reusePort lets this app coexist on the same UDP port as WSJT-CB
    // (multiple companions can each receive the datagram). Falls back
    // gracefully on OSes that don't support SO_REUSEPORT.
    RawDatagramSocket sock;
    try {
      sock = await RawDatagramSocket.bind(addr, port, reuseAddress: true, reusePort: true);
    } catch (_) {
      sock = await RawDatagramSocket.bind(addr, port, reuseAddress: true);
    }
    sock.readEventsEnabled = true;
    if (multicastGroup != null) {
      final group = InternetAddress(multicastGroup!);
      for (final ni in await NetworkInterface.list()) {
        try {
          sock.joinMulticast(group, ni);
        } catch (_) {
          // ignore interfaces that reject multicast
        }
      }
    }
    _socket = sock;
    sock.listen(_onEvent, onDone: () => _socket = null);
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket?.receive();
    if (dg == null) return;
    _lastPacket = DateTime.now();
    try {
      final msg = WsjtxReader.parse(dg.data);
      if (msg != null) _controller.add(msg);
    } catch (e, st) {
      // Swallow malformed packets; we don't want to kill the stream.
      // ignore: avoid_print
      print('wsjtx parse error: $e\n$st');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
