import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/core/constants/api_constants.dart';
import 'package:sic_mobile/core/realtime/realtime_service.dart';
import 'package:sic_mobile/core/realtime/ws_transport.dart';

class _FakeTransport implements WsTransport {
  final _controller = StreamController<dynamic>.broadcast();
  final List<String> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void send(String message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }

  void emit(String raw) => _controller.add(raw);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('wsNotificationsUrl est derivee du baseUrl (http->ws, sans /api)', () {
    expect(ApiConstants.wsNotificationsUrl,
        'ws://10.0.2.2:8000/ws/notifications/');
  });

  test('token present : connecte avec le token et dispatch connected + event',
      () async {
    final transport = _FakeTransport();
    Uri? connectedUri;
    var connectedCalls = 0;
    final events = <Map<String, dynamic>>[];

    final service = RealtimeService(
      tokenReader: () async => 'jwt-123',
      baseWsUrl: () => 'ws://test.local/ws/notifications/',
      onConnected: () => connectedCalls++,
      onEvent: events.add,
      connect: (uri) {
        connectedUri = uri;
        return transport;
      },
    );

    service.start();
    await _tick();
    expect(connectedUri.toString(),
        'ws://test.local/ws/notifications/?token=jwt-123');

    transport.emit(jsonEncode({'type': 'connected'}));
    await _tick();
    expect(connectedCalls, 1);

    transport.emit(jsonEncode(
        {'type': 'tx.completed', 'transaction_id': 't1', 'status': 'COMPLETED'}));
    await _tick();
    expect(events.single['type'], 'tx.completed');
    expect(events.single['status'], 'COMPLETED');

    await service.stop();
    expect(transport.closed, isTrue);
  });

  test('sans token : aucune connexion', () async {
    var connectCalls = 0;
    final service = RealtimeService(
      tokenReader: () async => null,
      baseWsUrl: () => 'ws://test.local/ws/notifications/',
      onConnected: () {},
      onEvent: (_) {},
      connect: (_) {
        connectCalls++;
        return _FakeTransport();
      },
    );

    service.start();
    await _tick();
    expect(connectCalls, 0);
    await service.stop();
  });

  test('heartbeat : un ping est envoye periodiquement', () async {
    final transport = _FakeTransport();
    final service = RealtimeService(
      tokenReader: () async => 'jwt',
      baseWsUrl: () => 'ws://x/ws/',
      onConnected: () {},
      onEvent: (_) {},
      connect: (_) => transport,
      heartbeat: const Duration(milliseconds: 20),
    );

    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(transport.sent.any((m) => m.contains('ping')), isTrue);
    await service.stop();
  });

  test('le pong est ignore (pas un evenement metier)', () async {
    final transport = _FakeTransport();
    final events = <Map<String, dynamic>>[];
    final service = RealtimeService(
      tokenReader: () async => 'jwt',
      baseWsUrl: () => 'ws://x/ws/',
      onConnected: () {},
      onEvent: events.add,
      connect: (_) => transport,
    );

    service.start();
    await _tick();
    transport.emit(jsonEncode({'type': 'pong'}));
    await _tick();
    expect(events, isEmpty);
    await service.stop();
  });
}
