import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(Uri uri, {Map<String, String>? headers}) =>
    WebSocketChannel.connect(uri);
