import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/helpers/isMobile.dart';
import 'package:hindsightchat/mixins/SidebarMixin.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          children: [
            SidebarNavItem(
              icon: Icons.people,
              label: 'Friends',
              isSelected: _pageState.selectedConversationId == null,
              onSelect: () => _pageState.selectConversation(null),
              mobilePageBuilder: (_) => const _FriendsPage(),
            ),
            const SizedBox(height: 16),
            const SidebarSection(title: 'Direct Messages'),
            for (final convo in dataProvider.conversations)
              SidebarNavItem(
                icon: Icons.account_circle,
                label: convo.isGroup
                    ? convo.name ?? 'Group Chat'
                    : convo.participants.isNotEmpty
                        ? convo.participants.first.username
                        : 'Unknown',
                isSelected: _pageState.selectedConversationId == convo.id,
                onSelect: () => _pageState.selectConversation(convo.id),
                mobilePageBuilder: (_) =>
                    _ConversationPage(conversationId: convo.id),
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
                ? _ConversationPage(
                    conversationId: _pageState.selectedConversationId!,
                  )
                : const _FriendsPage(),
          ),
        );
      },
    );
  }
}

/// Friends page content
class _FriendsPage extends StatelessWidget {
  const _FriendsPage();

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Online — ${dataProvider.friends.length}',
                style: const TextStyle(
                  color: Color(0xFF949BA4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final friend in dataProvider.friends)
                _FriendItem(friend: friend),
              if (dataProvider.friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No friends yet',
                      style: TextStyle(color: Color(0xFF949BA4)),
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

class _FriendItem extends StatelessWidget {
  final dynamic friend;

  const _FriendItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF5865F2),
            ),
            child: Center(
              child: Text(
                friend.user.username.isNotEmpty
                    ? friend.user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
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
                Text(
                  friend.user.displayName,
                  style: const TextStyle(
                    color: Color(0xFF949BA4),
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

class _ConversationPage extends StatelessWidget {
  final String conversationId;

  const _ConversationPage({required this.conversationId});

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final conversation = dataProvider.getConversation(conversationId);

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
          child: Row(
            children: [
              Text(
                '/',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Inter",
                  // italic
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                conversation?.participants.isNotEmpty == true
                    ? conversation!.participants.first.username
                    : 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Messages area (placeholder)
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: const Color(0xFF5865F2),
                  ),
                  child: Center(
                    child: Text(
                      conversation?.participants.isNotEmpty == true
                          ? conversation!.participants.first.username[0]
                                .toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  conversation?.participants.isNotEmpty == true
                      ? conversation!.participants.first.username
                      : 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is the beginning of your conversation',
                  style: TextStyle(color: Color(0xFF949BA4)),
                ),
              ],
            ),
          ),
        ),
        // Message input (placeholder)
        Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF383A40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle, color: Color(0xFFB5BAC1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Message @${conversation?.participants.isNotEmpty == true ? conversation!.participants.first.username : 'Unknown'}',
                    style: const TextStyle(color: Color(0xFF6D6F78)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


