import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hindsightchat/types/Activity.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hindsightchat/types/websocket/websocket-types.dart';

typedef EventCallback = void Function(Map<String, dynamic> data);

class WsMessage {
  final int op;
  final dynamic data;
  final String? event;
  final String? nonce;

  WsMessage({required this.op, this.data, this.event, this.nonce});

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
    op: json['op'] as int,
    data: json['d'],
    event: json['t'] as String?,
    nonce: json['nonce'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'op': op,
    if (data != null) 'd': data,
    if (event != null) 't': event,
    if (nonce != null) 'nonce': nonce,
  };
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  static const String _wsUrl = kDebugMode
      ? 'ws://localhost:3000/ws'
      : 'wss://api.hindsight.chat/ws';

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  String? _token;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  final Map<EventType, Set<EventCallback>> _listeners = {};
  final Map<String, Completer<Map<String, dynamic>>> _pendingAcks = {};
  final _connectionController = StreamController<bool>.broadcast();
  final _readyController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get readyStream => _readyController.stream;
  bool get isConnected => _isConnected;

  void connect(String token) {
    if (_isConnecting || _isConnected) return;
    _token = token;
    _shouldReconnect = true;
    _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting || _token == null) return;
    _isConnecting = true;

    try {
      debugPrint('[ws] connecting to $_wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      await _channel!.ready;
      debugPrint('[ws] connection ready, sending identify');

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _identify();
    } catch (e) {
      debugPrint('[ws] connection error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      debugPrint('[ws] received: $message');
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final msg = WsMessage.fromJson(json);
      _handleMessage(msg);
    } catch (e) {
      debugPrint('[ws] parse error: $e');
    }
  }

  void _handleMessage(WsMessage msg) {
    switch (msg.op) {
      case 0: // dispatch
        _handleDispatch(msg);
        break;
      case 11: // heartbeat ack
        debugPrint('[ws] heartbeat ack');
        break;
      case 12: // ready
        debugPrint('[ws] ready received');
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
        _startHeartbeat();
        _connectionController.add(true);
        if (msg.data != null) {
          _readyController.add(msg.data as Map<String, dynamic>);
        }
        break;
      case 13: // invalid session
        debugPrint('[ws] invalid session');
        _isConnected = false;
        _connectionController.add(false);
        disconnect();
        break;
    }
  }

  void _handleDispatch(WsMessage msg) {
    if (msg.nonce != null && _pendingAcks.containsKey(msg.nonce)) {
      _pendingAcks[msg.nonce]!.complete(
        msg.data as Map<String, dynamic>? ?? {},
      );
      _pendingAcks.remove(msg.nonce);
      return;
    }

    if (msg.event == null) return;

    debugPrint('[ws] dispatch: ${msg.event}');

    try {
      final eventType = eventTypeFromString(msg.event!);
      final callbacks = _listeners[eventType];
      if (callbacks != null && msg.data != null) {
        final data = msg.data as Map<String, dynamic>;
        for (final cb in callbacks.toList()) {
          cb(data);
        }
      }
    } catch (e) {
      debugPrint('[ws] unknown event: ${msg.event}');
    }
  }

  void _onError(Object error) {
    debugPrint('[ws] error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    debugPrint('[ws] connection closed');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    final wasConnected = _isConnected;
    _isConnected = false;
    _isConnecting = false;
    _heartbeatTimer?.cancel();
    _channel = null;

    if (wasConnected) {
      _connectionController.add(false);
    }

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[ws] max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    debugPrint(
      '[ws] reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, _connect);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      debugPrint('[ws] sending heartbeat');
      send(
        WsMessage(op: 1, data: {'ts': DateTime.now().millisecondsSinceEpoch}),
      );
    });
  }

  void _identify() {
    if (_token == null) return;
    debugPrint('[ws] sending identify');
    send(WsMessage(op: 2, data: {'token': _token}));
  }

  void send(WsMessage msg) {
    if (_channel == null) {
      debugPrint('[ws] cannot send, no channel');
      return;
    }
    try {
      final json = jsonEncode(msg.toJson());
      debugPrint('[ws] sending: $json');
      _channel!.sink.add(json);
    } catch (e) {
      debugPrint('[ws] send error: $e');
    }
  }

  Future<Map<String, dynamic>> sendWithAck(
    WsMessage msg, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<Map<String, dynamic>>();
    _pendingAcks[nonce] = completer;

    send(WsMessage(op: msg.op, data: msg.data, event: msg.event, nonce: nonce));

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingAcks.remove(nonce);
        throw TimeoutException('No ack received');
      },
    );
  }

  void on(EventType event, EventCallback callback) {
    _listeners.putIfAbsent(event, () => {});
    _listeners[event]!.add(callback);
  }

  void off(EventType event, EventCallback callback) {
    _listeners[event]?.remove(callback);
  }

  void offAll(EventType event) {
    _listeners.remove(event);
  }

  void disconnect() {
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _token = null;
    _reconnectAttempts = 0;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _readyController.close();
    _listeners.clear();
    _pendingAcks.clear();
  }

  void updatePresence(String status, {Activity? activity}) {
    send(
      WsMessage(
        op: 3,
        data: {
          'status': status,
          if (activity != null) 'activity': activity.toJson(),
        },
      ),
    );
  }

  void setFocus({String? channelId, String? serverId, String? conversationId}) {
    send(
      WsMessage(
        op: 4,
        data: {
          if (channelId != null) 'channel_id': channelId,
          if (serverId != null) 'server_id': serverId,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      ),
    );
  }

  void clearFocus() {
    send(WsMessage(op: 4, data: {}));
  }

  void startTyping({
    String? channelId,
    String? serverId,
    String? conversationId,
  }) {
    send(
      WsMessage(
        op: 20,
        data: {
          if (channelId != null) 'channel_id': channelId,
          if (serverId != null) 'server_id': serverId,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      ),
    );
  }

  void stopTyping({
    String? channelId,
    String? serverId,
    String? conversationId,
  }) {
    send(
      WsMessage(
        op: 21,
        data: {
          if (channelId != null) 'channel_id': channelId,
          if (serverId != null) 'server_id': serverId,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    String? channelId,
    String? serverId,
    String? conversationId,
    required String content,
    String? replyToId,
  }) {
    return sendWithAck(
      WsMessage(
        op: 22,
        data: {
          if (channelId != null) 'channel_id': channelId,
          if (serverId != null) 'server_id': serverId,
          if (conversationId != null) 'conversation_id': conversationId,
          'content': content,
          if (replyToId != null) 'reply_to_id': replyToId,
        },
      ),
    );
  }

  void ackMessage({
    String? channelId,
    String? conversationId,
    required String messageId,
  }) {
    send(
      WsMessage(
        op: 25,
        data: {
          if (channelId != null) 'channel_id': channelId,
          if (conversationId != null) 'conversation_id': conversationId,
          'message_id': messageId,
        },
      ),
    );
  }
}

final ws = WebSocketService();
