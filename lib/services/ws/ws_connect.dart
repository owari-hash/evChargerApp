import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_connect_stub.dart' if (dart.library.io) 'ws_connect_io.dart' as impl;

/// Opens a WebSocket with [headers] where the platform allows it. A browser
/// cannot set headers on a socket, but sends the site's own cookie itself.
WebSocketChannel connectWebSocket(Uri uri, {Map<String, String>? headers}) =>
    impl.connectWebSocket(uri, headers: headers);
