import 'package:flutter/material.dart';
import 'package:hindsightchat/mixins/websocket_mixin.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/websocket/websocket-types.dart';

class ChatWidget extends StatefulWidget {
  final String conversationId;
  const ChatWidget({super.key, required this.conversationId});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> with WebSocketMixin {
  final List<Map<String, dynamic>> _messages = [];
  final _controller = TextEditingController();
  final Set<String> _typingUsers = {};

  @override
  void initState() {
    super.initState();

    subscribe(EventType.dmMessageCreate, _onMessage);
    subscribe(EventType.typingStart, _onTypingStart);
    subscribe(EventType.typingStop, _onTypingStop);

    ws.setFocus(conversationId: widget.conversationId);
  }

  @override
  void dispose() {
    ws.clearFocus();
    _controller.dispose();
    super.dispose();
  }

  void _onMessage(Map<String, dynamic> data) {
    if (data['conversation_id'] != widget.conversationId) return;
    setState(() => _messages.add(data));
    ws.ackMessage(conversationId: widget.conversationId, messageId: data['id']);
  }

  void _onTypingStart(Map<String, dynamic> data) {
    if (data['conversation_id'] != widget.conversationId) return;
    setState(() => _typingUsers.add(data['user_id']));
  }

  void _onTypingStop(Map<String, dynamic> data) {
    if (data['conversation_id'] != widget.conversationId) return;
    setState(() => _typingUsers.remove(data['user_id']));
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    _controller.clear();
    ws.stopTyping(conversationId: widget.conversationId);

    await ws.sendMessage(conversationId: widget.conversationId, content: content);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              return ListTile(
                title: Text(msg['author']?['username'] ?? 'Unknown'),
                subtitle: Text(msg['content'] ?? ''),
              );
            },
          ),
        ),
        if (_typingUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${_typingUsers.length} user(s) typing...'),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => ws.startTyping(conversationId: widget.conversationId),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(hintText: 'Message'),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
            ],
          ),
        ),
      ],
    );
  }
}
