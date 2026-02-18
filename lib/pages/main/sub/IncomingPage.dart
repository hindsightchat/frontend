import 'package:flutter/material.dart';
import 'package:forui/widgets/button.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

class _FriendItem extends StatelessWidget {
  final FriendRequest friendship;

  const _FriendItem({required this.friendship});

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    // since its incoming, it would be the sender that sent the request, so we get the sender's user data
    final user = friendship.sender;

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
                  user.profilePicURL.isNotEmpty
                      ? user.profilePicURL
                      : "https://github.com/DwifteJB.png",
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
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Removed Spacer() and Expanded wrapper
          FButton(
            onPress: () async {
              await dataProvider.acceptFriendRequest(friendship.id);
            },
            variant: .outline,
            child: Text('Accept'),
          ),
          const SizedBox(width: 8),
          FButton(
            onPress: () async {
              await dataProvider.declineFriendRequest(friendship.id);
            },
            variant: .ghost,
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class IncomingFriendRequestPage extends StatefulWidget {
  const IncomingFriendRequestPage({super.key});

  @override
  State<IncomingFriendRequestPage> createState() =>
      _IncomingFriendRequestPageState();
}

class _IncomingFriendRequestPageState extends State<IncomingFriendRequestPage> {
  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    final incoming = dataProvider.incomingRequests;

    return Expanded(
      child: incoming.isEmpty
          ? const Center(
              child: Text(
                'No incoming requests yet',
                style: TextStyle(color: Color(0xFF949BA4)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (incoming.isNotEmpty) ...[
                  Text(
                    'INCOMING - ${incoming.length}',
                    style: const TextStyle(
                      color: Color(0xFF949BA4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final friendship in incoming)
                    _FriendItem(friendship: friendship),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
