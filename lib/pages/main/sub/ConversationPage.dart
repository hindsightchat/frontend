import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/components/Conversations/UserSidebar.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

class ConversationPage extends StatefulWidget {
  String conversationId;
  String serverId;

  ConversationPage({super.key, this.conversationId = "", this.serverId = ""});

  @override
  State<ConversationPage> createState() => ConversationPageState();
}

class ConversationPageState extends State<ConversationPage> {
  int get type => widget.conversationId.isEmpty ? 1 : 0;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _previousMessageCount = 0;
  bool _scrollPending = false;

  // typing state
  Timer? _typingTimer;
  DateTime? _lastTypingSent;
  static const _typingThrottle = Duration(
    seconds: 4,
  ); // resend typing every 4s while still typing
  static const _typingTimeout = Duration(
    seconds: 5,
  ); // stop typing after 5s of inactivity

  @override
  void initState() {
    super.initState();
    // if (widget.conversationId.isEmpty) {
    //   ws.setFocus(serverId: widget.serverId);
    // } else if (widget.conversationId.isNotEmpty) {
    //   ws.setFocus(conversationId: widget.conversationId);
    // } else {
    //   debugPrint(
    //     'ConversationPage initialized without conversationId or serverId',
    //   );
    // }
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
    _loadMessages();
  }

  @override
  void didUpdateWidget(covariant ConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // ensure we stop typing when leaving the page
    _stopTyping();
    _typingTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isEmpty) {
      _stopTyping();
      return;
    }

    final now = DateTime.now();

    // send typing start if we haven't sent one recently
    if (_lastTypingSent == null ||
        now.difference(_lastTypingSent!) > _typingThrottle) {
      if (type == 0) {
        ws.startTyping(conversationId: widget.conversationId);
      } else {
        ws.startTyping(serverId: widget.serverId);
      }
      _lastTypingSent = now;
    }

    // reset the typing timeout timer
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (_lastTypingSent != null) {
      if (type == 0) {
        ws.stopTyping(conversationId: widget.conversationId);
      } else {
        ws.stopTyping(serverId: widget.serverId);
      }
      _lastTypingSent = null;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMessages() async {
    final dataProvider = context.read<DataProvider>();
    final messages = await dataProvider.loadMessages(
      widget.conversationId,
      limit: 50,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasMore = messages.length >= 50;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;

    final dataProvider = context.read<DataProvider>();
    final messages = dataProvider.getMessages(widget.conversationId);
    if (messages.isEmpty) return;

    final oldestMessageId = messages.first.id;

    setState(() => _isLoadingMore = true);

    final scrollPositionFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    final newMessages = await dataProvider.loadMessages(
      widget.conversationId,
      limit: 50,
      before: oldestMessageId,
    );

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        _hasMore = newMessages.length >= 50;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final newMaxExtent = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(newMaxExtent - scrollPositionFromBottom);
        }
      });
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    void doScroll() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    }

    if (immediate) {
      doScroll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    // on web, defer the entire operation to avoid DOM text input conflicts
    if (kIsWeb) {
      Future.microtask(() => _doSendMessage(content));
    } else {
      _doSendMessage(content);
    }
  }

  Future<void> _doSendMessage(String content) async {
    if (_isSending) return;

    try {
      _messageController.clear();
    } catch (e) {
      debugPrint('Failed to clear message input: $e');
    }

    _stopTyping();

    // idk why web is so ass about this
    if (!kIsWeb) {
      setState(() => _isSending = true);
    }

    try {
      await ws.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );
      // _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to send message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return (maxScroll - currentScroll) <= 150;
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final authProvider = context.watch<AuthProvider>();
    final conversation = dataProvider.getConversation(widget.conversationId);
    final messages = dataProvider.getMessages(widget.conversationId);

    if (messages.length > _previousMessageCount &&
        _previousMessageCount > 0 &&
        !_isLoading &&
        !_scrollPending) {
      _scrollPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollPending = false;
        if (mounted && _isNearBottom()) {
          _scrollToBottom(immediate: true);
        }
      });
    }
    _previousMessageCount = messages.length;

    // // log all renders
    // String Time = DateTime.now().toIso8601String();
    // debugPrint(
    //   '[$Time] Rendering ConversationPage: conversationId=${widget.conversationId}, messages=${messages.length}, isLoading=$_isLoading, isSending=$_isSending, isLoadingMore=$_isLoadingMore',
    // );

    if (conversation == null) {
      return const Center(
        child: Text(
          'Conversation not found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final isGroup = conversation.participants.length > 1;

    final groupName = conversation.name;
    String participantName;

    if (groupName != null && groupName.isNotEmpty) {
      participantName = groupName;
    } else if (conversation.participants.isEmpty) {
      participantName = 'Unknown';
    } else {
      // Try to find a participant that isn't the current user
      final otherParticipants = conversation.participants
          .where((p) => p.id != authProvider.user?.id)
          .toList();
      if (otherParticipants.isNotEmpty) {
        participantName = otherParticipants.first.username;
      } else {
        // Fallback to first participant if all else fails
        participantName = conversation.participants.first.username;
      }
    }

    final isScreenSmall = MediaQuery.of(context).size.width < 1000;

    return Row(
      children: [
        // main chat area
        Expanded(
          child: Column(
            children: [
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: MessageBackgroundColor,
                  border: Border(
                    bottom: BorderSide(color: MessageBorderColor, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.transparent,
                      backgroundImage: NetworkImage(
                        "https://github.com/DwifteJB.png",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      participantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF5865F2),
                        ),
                      )
                    : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation with $participantName',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isLoadingMore && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF5865F2),
                                  ),
                                ),
                              ),
                            );
                          }

                          final messageIndex = _isLoadingMore
                              ? index - 1
                              : index;
                          final message = messages[messageIndex];
                          final showAvatar =
                              messageIndex == 0 ||
                              messages[messageIndex - 1].author.id !=
                                  message.author.id;

                          return _MessageBubble(
                            message: message,
                            showAvatar: showAvatar,
                            isFirst: messageIndex == 0 && !_isLoadingMore,
                          );
                        },
                      ),
              ),
              // typing indicator
              _TypingIndicator(
                conversationId: widget.conversationId,
                currentUserId: authProvider.user?.id ?? '',
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MessageSendBoxColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MessageBorderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: MutedTextColor),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onEditingComplete: () =>
                              {}, // keeps keyboard open on submit

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: "Inter",
                          ),
                          decoration: InputDecoration(
                            hintText: 'message @$participantName',
                            hintStyle: TextStyle(color: MutedTextColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          canRequestFocus: true,
                          autofocus: true,
                          onSubmitted: (_) => {_sendMessage()},
                          textInputAction: TextInputAction
                              .send, // show send button on keyboard
                          enabled: !_isSending,
                        ),
                      ),
                      if (_isSending)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MutedTextColor,
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.send, color: MutedTextColor),
                          onPressed: _sendMessage,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isScreenSmall && !isGroup)
          UserSidebar(
            otherUserId:
                conversation.participants
                    .where((p) => p.id != authProvider.user?.id)
                    .firstOrNull
                    ?.id ??
                conversation.participants.first.id,
            participantName: participantName,
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DirectMessage message;
  final bool showAvatar;
  final bool isFirst;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : (showAvatar ? 16 : 4),
        left: 52,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showAvatar)
            Positioned(
              left: -52,
              top: 0,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.transparent,
                backgroundImage: NetworkImage(
                  "https://github.com/DwifteJB.png",
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar)
                Row(
                  children: [
                    Text(
                      message.author.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        fontFamily: "Inter",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF767676),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                message.content,
                style: const TextStyle(
                  color: Color(0xFFDBDEE1),
                  fontSize: 14,
                  fontFamily: "Inter",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    // if (diff.inDays == 0) {
    //   return 'today at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    // } else if (diff.inDays == 1) {
    //   return 'yesterday at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    // } else {
    //   return '${time.day}/${time.month}/${time.year}';
    // }

    // previous implementation doesnt work when it goes past 00:00, new way!

    if (diff.inSeconds < 60) {
      return 'just now'; // e.g less than 1 min ago
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago'; // e.g 5m ago, less than 1 hour
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago'; // e.g 3h ago, less than 1 day
    } else {
      // fallback to date for anything older than 1 day to: e.g 04:30 12/9
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.day}/${time.month} ';
    }
  }
}

class _TypingIndicator extends StatelessWidget {
  final String conversationId;
  final String currentUserId;

  const _TypingIndicator({
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final typingUserIds = dataProvider
        .getTypingUsers(conversationId)
        .where((id) => id != currentUserId)
        .toList();

    print(typingUserIds);

    if (typingUserIds.isEmpty) {
      return const SizedBox.shrink();
    }

    // get usernames for typing users
    final typingNames = typingUserIds.map((id) {
      final user = dataProvider.getUser(id);
      return user?.username ?? 'Someone';
    }).toList();

    String text;
    if (typingNames.length == 1) {
      text = '${typingNames[0]} is typing...';
    } else if (typingNames.length == 2) {
      text = '${typingNames[0]} and ${typingNames[1]} are typing...';
    } else {
      text = 'Several people are typing...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _TypingDots(),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: MutedTextColor,
              fontSize: 12,
              fontFamily: "Inter",
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value + delay) % 1.0;
            final opacity = (1.0 - (progress - 0.5).abs() * 2).clamp(0.3, 1.0);

            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: MutedTextColor.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
