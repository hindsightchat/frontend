import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

class ConversationPage extends StatefulWidget {
  final String conversationId;

  const ConversationPage({super.key, required this.conversationId});

  @override
  State<ConversationPage> createState() => ConversationPageState();
}

class ConversationPageState extends State<ConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    ws.setFocus(conversationId: widget.conversationId);
    _scrollController.addListener(_onScroll);
    _loadMessages();
  }

  @override
  void dispose() {
    ws.clearFocus();
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ws.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to send message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final conversation = dataProvider.getConversation(widget.conversationId);
    final messages = dataProvider.getMessages(widget.conversationId);

    if (conversation == null) {
      return const Center(
        child: Text(
          'Conversation not found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final participantName = conversation.participants.isNotEmpty
        ? conversation.participants.first.username
        : 'Unknown';

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
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
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
                          focusNode: _focusNode,
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
                          onSubmitted: (_) => _sendMessage(),
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
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: UserProfileSideBarColor,

            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MessageBorderColor, width: 1),
                  ),
                  color: MessageBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: SizedBox.shrink(),
              ),
              // panel content
              Expanded(
                child: Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // banner fill width of panel and height of 100px, with rounded corners
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: MessageBackgroundColor,
                            ),
                            // image take entire container but maintain aspect ratio and be centered
                            // as base64
                            child: Image.network(
                              "https://i.redd.it/i9zw9k4hoqj51.jpg",
                              fit: BoxFit.cover,
                            ),
                          ),
                          // profile picture 80x80px, circular, with border of 4px in UserProfileSideBarColor, overlapping banner and centered horizontally
                          Positioned(
                            top: 60,
                            left: 20,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: UserProfileSideBarColor,
                                  width: 4,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    "https://github.com/DwifteJB.png",
                                    
                                  ),
                                  
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              participantName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Inter",
                              ),
                            ),

                            SizedBox(height: 10),

                            Container(
                              width: double.infinity,

                              decoration: BoxDecoration(
                                color: UserProfileDescriptionBGColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'placeholder description',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: "Inter",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

    if (diff.inDays == 0) {
      return 'today at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'yesterday at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
