class UserBrief {
  final String id;
  final String username;
  final String domain;

  const UserBrief({required this.id, required this.username, required this.domain});

  factory UserBrief.fromJson(Map<String, dynamic> json) => UserBrief(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'username': username, 'domain': domain};

  String get displayName => '$username.$domain';
}

class Friendship {
  final String id;
  final UserBrief user;
  final String conversationId;
  final DateTime since;

  const Friendship({
    required this.id,
    required this.user,
    required this.conversationId,
    required this.since,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) => Friendship(
    id: json['id'] as String? ?? '',
    user: UserBrief.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    conversationId: json['conversation_id'] as String? ?? '',
    since: DateTime.tryParse(json['since'] as String? ?? '') ?? DateTime.now(),
  );
}

class FriendRequest {
  final String id;
  final UserBrief sender;
  final UserBrief receiver;
  final int status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String? ?? '',
    sender: UserBrief.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
    receiver: UserBrief.fromJson(json['receiver'] as Map<String, dynamic>? ?? {}),
    status: json['status'] as int? ?? 0,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class Conversation {
  final String id;
  final String? name;
  final bool isGroup;
  final List<UserBrief> participants;
  final DateTime? lastReadAt;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    this.name,
    required this.isGroup,
    required this.participants,
    this.lastReadAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String? ?? '',
    name: json['name'] as String?,
    isGroup: json['is_group'] as bool? ?? false,
    participants: (json['participants'] as List<dynamic>?)
        ?.map((e) => UserBrief.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    lastReadAt: json['last_read_at'] != null 
        ? DateTime.tryParse(json['last_read_at'] as String) 
        : null,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  String displayName(String currentUserId) {
    if (name != null && name!.isNotEmpty) return name!;
    final others = participants.where((p) => p.id != currentUserId).toList();
    if (others.isEmpty) return 'Empty conversation';
    return others.map((p) => p.username).join(', ');
  }
}

class Server {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String ownerId;
  final DateTime joinedAt;

  const Server({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.ownerId,
    required this.joinedAt,
  });

  factory Server.fromJson(Map<String, dynamic> json) => Server(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    icon: json['icon'] as String?,
    ownerId: json['owner_id'] as String? ?? '',
    joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ?? DateTime.now(),
  );
}
