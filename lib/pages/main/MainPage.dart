import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/components/Dashboard/CreateConversation.dart';
import 'package:hindsightchat/helpers/isMobile.dart';
import 'package:hindsightchat/mixins/SidebarMixin.dart';
import 'package:hindsightchat/pages/main/sub/ConversationPage.dart';
import 'package:hindsightchat/pages/main/sub/FriendsSidePage.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

enum MainPageSection { friends, messageRequests, conversations }

// provider tracks selected conversation and friends list for the sidebar
class MainPageState extends ChangeNotifier {
  MainPageSection selectedSection = MainPageSection.friends;
  String? _selectedConversationId;
  bool _isDisposed = false;

  String? get selectedConversationId => _selectedConversationId;
  bool get isDisposed => _isDisposed;

  void setSelectedSection(MainPageSection section) {
    if (_isDisposed) return;
    selectedSection = section;
    if (section != MainPageSection.conversations) {
      if (_selectedConversationId != null) {
        ws.clearFocus();
        _selectedConversationId = null;
      }
    }
    notifyListeners();
  }

  void selectConversation(String? id) {
    if (_isDisposed) return;
    if (id != null) {
      ws.setFocus(conversationId: id);
    }
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

    final conversations = dataProvider.conversations;
    conversations.sort((a, b) {
      final aLast = a.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bLast = b.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bLast.compareTo(aLast);
    });

    return ListenableBuilder(
      listenable: _pageState,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SidebarNavItem(
              icon: Icons.people,
              label: 'friends',
              isSelected: _pageState.selectedSection == MainPageSection.friends,
              onSelect: () =>
                  _pageState.setSelectedSection(MainPageSection.friends),
              mobilePageBuilder: (_) => const FriendsPage(),
            ),
            SidebarNavItem(
              icon: Icons.mail,
              label: 'message requests',
              isSelected:
                  _pageState.selectedSection == MainPageSection.messageRequests,
              onSelect: () => _pageState.setSelectedSection(
                MainPageSection.messageRequests,
              ),
              mobilePageBuilder: (_) => const FriendsPage(),
            ),
            const SizedBox(height: 16),
            SidebarSection(
              title: 'Direct Messages',
              onAddPressed: () async {
                final conversationId = await showCreateConversationDialog(
                  context,
                );
                if (conversationId != null) {
                  _pageState.selectConversation(conversationId);
                  dataProvider.markConversationRead(conversationId);
                  _pageState.setSelectedSection(MainPageSection.conversations);
                }
              },
            ),
            for (final convo in conversations)
              _ConversationSidebarItem(
                convo: convo,
                isSelected:
                    convo.id == _pageState.selectedConversationId &&
                    _pageState.selectedSection == MainPageSection.conversations,
                hasUnread: dataProvider.hasUnread(convo.id),
                onSelect: () {
                  _pageState.selectConversation(convo.id);
                  dataProvider.markConversationRead(convo.id);
                  _pageState.setSelectedSection(MainPageSection.conversations);
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

  Widget getCurrentPage() {
    switch (_pageState.selectedSection) {
      case MainPageSection.friends:
        return const FriendsPage();
      case MainPageSection.messageRequests:
        return const FriendsPage();
      case MainPageSection.conversations:
        if (_pageState.selectedConversationId != null) {
          return ConversationPage(
            key: ValueKey(_pageState.selectedConversationId),
            conversationId: _pageState.selectedConversationId!,
          );
        } else {
          return const FriendsPage();
        }
    }
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

          child: Container(
            decoration: BoxDecoration(
              color: MessageBackgroundColor,
              border: Border(
                left: BorderSide(color: MessageBorderColor, width: 1),
                top: BorderSide(color: MessageBorderColor, width: 1),
              ),
            ),
            child: getCurrentPage(),
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
    DataProvider dataProvider = Provider.of<DataProvider>(
      context,
      listen: true,
    );

    // if not group, get participents status
    String status = "offline";
    if (!widget.convo.isGroup && widget.convo.participants.isNotEmpty) {
      final otherUserId = widget.convo.participants.first.id;
      final otherUser = dataProvider.getUser(otherUserId);
      status = otherUser?.presence?.status ?? 'offline';
    }

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),

                      image: const DecorationImage(
                        image: NetworkImage("https://github.com/DwifteJB.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (!widget.convo.isGroup)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: MainAccessColor(status),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: MessageBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
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
