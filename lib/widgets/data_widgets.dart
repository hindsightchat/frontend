import 'package:flutter/material.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:provider/provider.dart';

class FriendsListWidget extends StatelessWidget {
  const FriendsListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        if (data.incomingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Incoming Requests', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...data.incomingRequests.map((req) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: Text(req.sender.displayName),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => data.acceptFriendRequest(req.id),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => data.declineFriendRequest(req.id),
                ),
              ],
            ),
          )),
          const Divider(),
        ],
        if (data.outgoingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Outgoing Requests', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...data.outgoingRequests.map((req) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.hourglass_empty)),
            title: Text(req.receiver.displayName),
            subtitle: const Text('Pending'),
            trailing: IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => data.cancelFriendRequest(req.id),
            ),
          )),
          const Divider(),
        ],
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Friends', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (data.friends.isEmpty)
          const ListTile(title: Text('No friends yet'))
        else
          ...data.friends.map((friend) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(friend.user.displayName),
            onTap: () {
              final conv = data.getConversation(friend.conversationId);
              if (conv != null) {
                // navigate to conversation
              }
            },
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'message', child: Text('Message')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
              onSelected: (value) {
                if (value == 'remove') {
                  data.removeFriend(friend.user.id);
                }
              },
            ),
          )),
      ],
    );
  }
}

class ConversationsListWidget extends StatelessWidget {
  final String currentUserId;
  final void Function(String conversationId)? onConversationTap;

  const ConversationsListWidget({
    super.key,
    required this.currentUserId,
    this.onConversationTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.conversations.isEmpty) {
      return const Center(child: Text('No conversations'));
    }

    return ListView.builder(
      itemCount: data.conversations.length,
      itemBuilder: (_, i) {
        final conv = data.conversations[i];
        return ListTile(
          leading: CircleAvatar(
            child: Icon(conv.isGroup ? Icons.group : Icons.person),
          ),
          title: Text(conv.displayName(currentUserId)),
          subtitle: conv.isGroup 
              ? Text('${conv.participants.length} participants')
              : null,
          onTap: () => onConversationTap?.call(conv.id),
        );
      },
    );
  }
}

class ServersListWidget extends StatelessWidget {
  final void Function(String serverId)? onServerTap;

  const ServersListWidget({super.key, this.onServerTap});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.servers.isEmpty) {
      return const Center(child: Text('No servers'));
    }

    return ListView.builder(
      itemCount: data.servers.length,
      itemBuilder: (_, i) {
        final server = data.servers[i];
        return ListTile(
          leading: server.icon != null
              ? CircleAvatar(backgroundImage: NetworkImage(server.icon!))
              : const CircleAvatar(child: Icon(Icons.dns)),
          title: Text(server.name),
          subtitle: server.description != null ? Text(server.description!) : null,
          onTap: () => onServerTap?.call(server.id),
        );
      },
    );
  }
}
