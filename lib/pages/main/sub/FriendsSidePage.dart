import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/pages/main/sub/AddFriendPage.dart';
import 'package:hindsightchat/pages/main/sub/IncomingPage.dart';
import 'package:hindsightchat/pages/main/sub/PendingPage.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

enum FriendPageSection { friends, add, incomingrequests, pending }

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  FriendPageSection selectedSection = FriendPageSection.friends;

  Widget getCurrentPage(BuildContext context) {
    switch (selectedSection) {
      case FriendPageSection.friends:
        return MainFriendsPage(context);
      case FriendPageSection.add:
        return AddFriendPage();
      case FriendPageSection.incomingrequests:
        return IncomingFriendRequestPage();
      case FriendPageSection.pending:
        return PendingFriendRequestPage(); // TODO: replace
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(context, getCurrentPage(context));
  }

  Widget LayoutBuilder(BuildContext context, Widget child) {
    DataProvider dataProvider = context.watch<DataProvider>();

    // count incoming friend requests
    final incomingRequests = dataProvider.incomingRequests.length;
    final pendingRequests = dataProvider.outgoingRequests.length;

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
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Row(
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
              SizedBox(width: 16),
              // all button
              FButton(
                onPress: () => {
                  setState(() => selectedSection = FriendPageSection.friends),
                },
                style: FButtonStyle.ghost(),
                child: Text(
                  'All',
                  style: TextStyle(
                    color: selectedSection == FriendPageSection.friends
                        ? Colors.white
                        : Color(0xFF949BA4),
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 8),
              FButton(
                onPress: () => {
                  setState(
                    () => selectedSection = FriendPageSection.incomingrequests,
                  ),
                },
                style: FButtonStyle.ghost(),
                child: Text(
                  'Incoming ${incomingRequests > 0 ? '($incomingRequests)' : ''}',
                  style: TextStyle(
                    color: selectedSection == FriendPageSection.incomingrequests
                        ? Colors.white
                        : Color(0xFF949BA4),
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 8),
              FButton(
                onPress: () => {
                  setState(() => selectedSection = FriendPageSection.pending),
                },
                style: FButtonStyle.ghost(),
                child: Text(
                  'Pending ${pendingRequests > 0 ? '($pendingRequests)' : ''}',
                  style: TextStyle(
                    color: selectedSection == FriendPageSection.pending
                        ? Colors.white
                        : Color(0xFF949BA4),
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Online, All, Pending and an add button on the right
              Spacer(),
              FButton(
                child: Icon(Icons.person_add, color: Colors.white, size: 20),
                onPress: () => {
                  setState(() => selectedSection = FriendPageSection.add),
                },
                style: FButtonStyle.outline(),
              ),
            ],
          ),
        ),
        // Friends list
        Expanded(child: child),
      ],
    );
  }

  Widget MainFriendsPage(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    // Separate online and offline friends based on users cache
    final onlineFriends = dataProvider.friends.where((f) {
      final user = dataProvider.getUser(f.visibleUserId);
      return user?.isOnline ?? false;
    }).toList();

    final offlineFriends = dataProvider.friends.where((f) {
      final user = dataProvider.getUser(f.visibleUserId);
      return user?.isOffline ?? true;
    }).toList();

    return Expanded(
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
                  for (final friendship in onlineFriends)
                    _FriendItem(friendship: friendship),
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
                  for (final friendship in offlineFriends)
                    _FriendItem(friendship: friendship),
                ],
              ],
            ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final Friendship friendship;

  const _FriendItem({required this.friendship});

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final user = dataProvider.getUser(friendship.visibleUserId);

    final isOnline = user?.isOnline ?? false;
    final activity = user?.presence?.activity;
    final status = user?.presence?.status ?? 'offline';
    final profilePic = user?.profilePicURL ?? '';
    final username = user?.username ?? friendship.visibleUsername;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  profilePic.isNotEmpty
                      ? profilePic
                      : "https://github.com/DwifteJB.png",
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: MainAccessColor(status),
                    shape: BoxShape.circle,
                    border: Border.all(color: MessageBackgroundColor, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
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
