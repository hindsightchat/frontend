import 'package:flutter/widgets.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/websocket/websocket-types.dart';

mixin WebSocketMixin<T extends StatefulWidget> on State<T> {
  final List<_Subscription> _subscriptions = [];

  void subscribe(EventType event, EventCallback callback) {
    ws.on(event, callback);
    _subscriptions.add(_Subscription(event, callback));
  }

  void unsubscribe(EventType event, EventCallback callback) {
    ws.off(event, callback);
    _subscriptions.removeWhere((s) => s.event == event && s.callback == callback);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      ws.off(sub.event, sub.callback);
    }
    _subscriptions.clear();
    super.dispose();
  }
}

class _Subscription {
  final EventType event;
  final EventCallback callback;
  _Subscription(this.event, this.callback);
}
