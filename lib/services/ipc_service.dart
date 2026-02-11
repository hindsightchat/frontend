import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef IpcMessageCallback = void Function(Map<String, dynamic> data);

class IpcServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];
  final List<IpcMessageCallback> _listeners = [];
  bool _isRunning = false;
  
  static const int defaultPort = 19542;

  bool get isRunning => _isRunning;

  Future<void> start({int port = defaultPort}) async {
    if (_isRunning) return;

    try {
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      _isRunning = true;
      debugPrint('[ipc] server listening on port $port');

      _server!.listen(
        _handleClient,
        onError: (error) {
          debugPrint('[ipc] server error: $error');
        },
        onDone: () {
          debugPrint('[ipc] server closed');
          _isRunning = false;
        },
      );
    } catch (e) {
      debugPrint('[ipc] failed to start server: $e');
    }
  }

  void _handleClient(Socket client) {
    debugPrint('[ipc] client connected: ${client.remoteAddress.address}:${client.remotePort}');
    _clients.add(client);

    final buffer = StringBuffer();

    client.listen(
      (data) {
        buffer.write(utf8.decode(data));
        
        while (buffer.toString().contains('\n')) {
          final content = buffer.toString();
          final newlineIndex = content.indexOf('\n');
          final line = content.substring(0, newlineIndex);
          buffer.clear();
          buffer.write(content.substring(newlineIndex + 1));
          
          if (line.isNotEmpty) {
            _processMessage(line);
          }
        }
        
        final remaining = buffer.toString();
        if (remaining.isNotEmpty && !remaining.contains('\n')) {
          try {
            _processMessage(remaining);
            buffer.clear();
          } catch (_) {}
        }
      },
      onError: (error) {
        debugPrint('[ipc] client error: $error');
        _clients.remove(client);
      },
      onDone: () {
        debugPrint('[ipc] client disconnected');
        _clients.remove(client);
      },
    );
  }

  void _processMessage(String message) {
    debugPrint('[ipc] received: $message');
    
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      for (final listener in _listeners) {
        listener(json);
      }
    } catch (e) {
      debugPrint('[ipc] failed to parse message: $e');
    }
  }

  void onMessage(IpcMessageCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(IpcMessageCallback callback) {
    _listeners.remove(callback);
  }

  void broadcast(Map<String, dynamic> data) {
    final message = '${jsonEncode(data)}\n';
    final bytes = utf8.encode(message);
    
    for (final client in _clients.toList()) {
      try {
        client.add(bytes);
      } catch (e) {
        debugPrint('[ipc] failed to send to client: $e');
        _clients.remove(client);
      }
    }
  }

  Future<void> stop() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    _isRunning = false;
    _listeners.clear();
    debugPrint('[ipc] server stopped');
  }

  void dispose() {
    stop();
  }
}
