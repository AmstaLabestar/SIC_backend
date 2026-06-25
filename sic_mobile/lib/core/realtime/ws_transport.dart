import 'package:web_socket_channel/web_socket_channel.dart';

/// Abstraction du transport WebSocket : permet d'injecter un faux transport en
/// test (sans vraie connexion reseau).
abstract class WsTransport {
  Stream<dynamic> get stream;
  void send(String message);
  Future<void> close();
}

/// Fabrique un transport pour une URI donnee.
typedef WsConnect = WsTransport Function(Uri uri);

/// Implementation reelle adossee a `web_socket_channel`.
class WebSocketChannelTransport implements WsTransport {
  WebSocketChannelTransport(Uri uri) : _channel = WebSocketChannel.connect(uri);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() => _channel.sink.close();
}
