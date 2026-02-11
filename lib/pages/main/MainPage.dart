import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/helpers/isMobile.dart';
import 'package:hindsightchat/mixins/SidebarMixin.dart';
import 'package:hindsightchat/pages/main/ConversationPage.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

// provider tracks selected conversation and friends list for the sidebar
class MainPageState extends ChangeNotifier {
  String? _selectedConversationId;
  bool _isDisposed = false;

  String? get selectedConversationId => _selectedConversationId;
  bool get isDisposed => _isDisposed;

  void selectConversation(String? id) {
    if (_isDisposed) return;
    _selectedConversationId = id;
    notifyListeners();
  }

  // mark as disposed when gone
  void markDisposed() {
    _isDisposed = true;
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SidebarMixin {
  final MainPageState _pageState = MainPageState();

  @override
  void dispose() {
    _pageState.markDisposed();
    super.dispose();
  }

  @override
  Widget? buildSidebar(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    return ListenableBuilder(
      listenable: _pageState,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SidebarNavItem(
              icon: Icons.people,
              label: 'All Friends',
              isSelected: _pageState.selectedConversationId == null,
              onSelect: () => _pageState.selectConversation(null),
              mobilePageBuilder: (_) => const _FriendsPage(),
            ),
            SidebarNavItem(
              icon: Icons.people,
              label: 'Message requests',
              isSelected: _pageState.selectedConversationId == null,
              onSelect: () => _pageState.selectConversation(null),
              mobilePageBuilder: (_) => const _FriendsPage(),
            ),
            const SizedBox(height: 16),
            const SidebarSection(title: 'Direct Messages'),
            for (final convo in dataProvider.conversations)
              _ConversationSidebarItem(
                convo: convo,
                isSelected: _pageState.selectedConversationId == convo.id,
                hasUnread: dataProvider.hasUnread(convo.id),
                onSelect: () {
                  _pageState.selectConversation(convo.id);
                  dataProvider.markConversationRead(convo.id);
                },
                mobilePageBuilder: (_) => ConversationPage(
                  key: ValueKey(convo.id),
                  conversationId: convo.id,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    // mobile (uses sheet)
    if (mobile) {
      return const SizedBox.shrink();
    }

    // desktop
    return ListenableBuilder(
      listenable: _pageState,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.only(right: 20),
          child: Container(
            decoration: BoxDecoration(
              color: MessageBackgroundColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(30),
              ),
              border: Border(
                right: BorderSide(color: MessageBorderColor, width: 1),
                top: BorderSide(color: MessageBorderColor, width: 1),
              ),
            ),
            child: _pageState.selectedConversationId != null
                ? ConversationPage(
                    key: ValueKey(_pageState.selectedConversationId),
                    conversationId: _pageState.selectedConversationId!,
                  )
                : const _FriendsPage(),
          ),
        );
      },
    );
  }
}

class _ConversationSidebarItem extends StatefulWidget {
  final Conversation convo;
  final bool isSelected;
  final bool hasUnread;
  final VoidCallback onSelect;
  final Widget Function(BuildContext)? mobilePageBuilder;

  const _ConversationSidebarItem({
    required this.convo,
    required this.isSelected,
    required this.hasUnread,
    required this.onSelect,
    this.mobilePageBuilder,
  });

  @override
  State<_ConversationSidebarItem> createState() =>
      _ConversationSidebarItemState();
}

class _ConversationSidebarItemState extends State<_ConversationSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.convo.isGroup
        ? widget.convo.name ?? 'Group Chat'
        : widget.convo.participants.isNotEmpty
        ? widget.convo.participants.first.username
        : 'Unknown';

    // White text when unread, otherwise normal colors
    final textColor = widget.hasUnread
        ? Colors.white
        : (widget.isSelected || _isHovered
              ? const Color(0xFFDBDEE1)
              : const Color(0xFF949BA4));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onSelect();
          if (widget.mobilePageBuilder != null) {
            openMobilePage(context, widget.mobilePageBuilder!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Icon(
              //   Icons.account_circle,
              //   size: 20,
              //   color: widget.isSelected || _isHovered
              //       ? const Color(0xFFDBDEE1)
              //       : const Color(0xFF949BA4),
              // ),
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                  "https://github.com/DwifteJB.png",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: widget.hasUnread || widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsPage extends StatelessWidget {
  const _FriendsPage();

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    // Separate online and offline friends
    final onlineFriends = dataProvider.friends
        .where((f) => f.user.isOnline)
        .toList();
    final offlineFriends = dataProvider.friends
        .where((f) => f.user.isOffline)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title bar
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
          child: const Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Friends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Friends list
        Expanded(
          child: dataProvider.friends.isEmpty
              ? const Center(
                  child: Text(
                    'No friends yet',
                    style: TextStyle(color: Color(0xFF949BA4)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (onlineFriends.isNotEmpty) ...[
                      Text(
                        'ONLINE - ${onlineFriends.length}',
                        style: const TextStyle(
                          color: Color(0xFF949BA4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final friend in onlineFriends)
                        _FriendItem(friend: friend),
                      const SizedBox(height: 16),
                    ],
                    if (offlineFriends.isNotEmpty) ...[
                      Text(
                        'OFFLINE - ${offlineFriends.length}',
                        style: const TextStyle(
                          color: Color(0xFF949BA4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final friend in offlineFriends)
                        _FriendItem(friend: friend),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FriendItem extends StatelessWidget {
  final Friendship friend;

  const _FriendItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    final isOnline = friend.user.isOnline;
    final activity = friend.user.presence?.activity;

    // Status indicator color
    Color statusColor;
    switch (friend.user.presence?.status) {
      case 'online':
        statusColor = const Color(0xFF3BA55C); // Green
        break;
      case 'idle':
        statusColor = const Color(0xFFFAA61A); // Yellow/Orange
        break;
      case 'dnd':
        statusColor = const Color(0xFFED4245); // Red
        break;
      default:
        statusColor = const Color(0xFF747F8D); // Gray (offline)
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          // Avatar with status indicator
          Stack(
            children: [
              // Container(
              //   width: 40,
              //   height: 40,
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(20),
              //     color: const Color(0xFF5865F2),
              //   ),
              //   child: Center(
              //     child: Text(
              //       friend.user.username.isNotEmpty
              //           ? friend.user.username[0].toUpperCase()
              //           : '?',
              //       style: const TextStyle(
              //         color: Colors.white,
              //         fontWeight: FontWeight.w600,
              //       ),
              //     ),
              //   ),
              // ),
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  friend.user.profilePicURL.isNotEmpty
                      ? friend.user.profilePicURL
                      : "https://github.com/DwifteJB.png",
                ),
              ),
              // Status indicator
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: MessageBackgroundColor, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (activity != null && activity.hasActivity)
                  Text(
                    activity.details.isNotEmpty
                        ? activity.details
                        : activity.state,
                    style: const TextStyle(
                      color: Color(0xFF949BA4),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline
                          ? const Color(0xFF3BA55C)
                          : const Color(0xFF949BA4),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
