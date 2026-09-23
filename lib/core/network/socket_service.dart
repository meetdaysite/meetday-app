import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/environment.dart';

class SocketService {
  SocketService._();

  static final SocketService _instance = SocketService._();
  static SocketService get instance => _instance;

  io.Socket? _socket;
  bool _isConnected = false;

  void connect({required String token, required AppConfig config}) {
    if (_socket != null) {
      disconnect();
    }

    final socketOptions = io.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build();

    _socket = io.io(config.socketUrl, socketOptions);
    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('Socket connected');
    });
    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('Socket disconnected');
    });
    _socket!.onConnectError((data) {
      debugPrint('Socket connect error: $data');
    });
    _socket!.on('notification', (data) {
      debugPrint('Socket notification: $data');
    });
    _socket!.on('chat_message', (data) {
      debugPrint('Socket chat message: $data');
    });
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}

final socketServiceProvider = Provider<SocketService>(
  (ref) => SocketService.instance,
);
