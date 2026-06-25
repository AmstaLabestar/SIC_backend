import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ws_transport.dart';

/// Gere la connexion WebSocket temps reel des notifications.
///
/// - Connexion authentifiee par JWT (jeton lu a chaque tentative -> toujours
///   frais), passe en query string.
/// - Reconnexion automatique avec backoff exponentiel (financier : on ne reste
///   jamais muet longtemps).
/// - Heartbeat (ping) pour garder la connexion vivante.
/// - **Re-synchronisation a chaque (re)connexion** : le WebSocket ne porte
///   jamais la verite ; il declenche un re-fetch via [onConnected].
class RealtimeService {
  RealtimeService({
    required Future<String?> Function() tokenReader,
    required String Function() baseWsUrl,
    required void Function(Map<String, dynamic> event) onEvent,
    required VoidCallback onConnected,
    WsConnect? connect,
    this.heartbeat = const Duration(seconds: 25),
    this.maxBackoff = const Duration(seconds: 30),
  })  : _tokenReader = tokenReader,
        _baseWsUrl = baseWsUrl,
        _onEvent = onEvent,
        _onConnected = onConnected,
        _connect = connect ?? ((uri) => WebSocketChannelTransport(uri));

  final Future<String?> Function() _tokenReader;
  final String Function() _baseWsUrl;
  final void Function(Map<String, dynamic>) _onEvent;
  final VoidCallback _onConnected;
  final WsConnect _connect;
  final Duration heartbeat;
  final Duration maxBackoff;

  bool _active = false;
  WsTransport? _transport;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _attempt = 0;

  bool get isActive => _active;

  /// Demarre le temps reel (idempotent). Sans session, ne fait rien.
  void start() {
    if (_active) return;
    _active = true;
    _open();
  }

  /// Arrete et ferme proprement la connexion.
  Future<void> stop() async {
    _active = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    final sub = _sub;
    final transport = _transport;
    _sub = null;
    _transport = null;
    _attempt = 0;
    await sub?.cancel();
    await transport?.close();
  }

  Future<void> _open() async {
    if (!_active) return;
    String? token;
    try {
      token = await _tokenReader();
    } catch (_) {
      // Lecture du jeton en echec (ex. erreur secure-storage) : on retente.
      _scheduleReconnect();
      return;
    }
    if (!_active) return;
    if (token == null || token.isEmpty) {
      return; // pas de session : on reconnectera via start() apres login
    }
    try {
      final uri = Uri.parse('${_baseWsUrl()}?token=$token');
      final transport = _connect(uri);
      _transport = transport;
      _sub = transport.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'connected':
        _attempt = 0; // connexion etablie -> reset du backoff
        _onConnected(); // re-sync (re-fetch via REST = source de verite)
      case 'pong':
        break;
      default:
        _onEvent(data);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeat, (_) {
      try {
        _transport?.send(jsonEncode({'type': 'ping'}));
      } catch (_) {/* la reconnexion gere la coupure */}
    });
  }

  void _scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _transport = null;
    if (!_active) return;
    _reconnectTimer?.cancel();
    final delay = _backoffDelay();
    _attempt++;
    _reconnectTimer = Timer(delay, _open);
  }

  Duration _backoffDelay() {
    // 1, 2, 4, 8... secondes, plafonne a maxBackoff.
    final exp = _attempt.clamp(0, 5);
    final seconds = (1 << exp).clamp(1, maxBackoff.inSeconds);
    return Duration(seconds: seconds);
  }
}
