class Presence {
  final String status;
  final Activity? activity;
  final int updatedAt;

  const Presence({
    required this.status,
    this.activity,
    required this.updatedAt,
  });

  factory Presence.fromJson(Map<String, dynamic> json) => Presence(
    status: json['status'] as String? ?? 'offline',
    activity: json['activity'] != null
        ? Activity.fromJson(json['activity'] as Map<String, dynamic>)
        : null,
    updatedAt: json['updated_at'] as int? ?? 0,
  );

  bool get isOnline =>
      status == 'online' || status == 'idle' || status == 'dnd';
  bool get isOffline => status == 'offline' || status.isEmpty;
}

class Activity {
  final String smallText;
  final String largeText;
  final String details;
  final String state;

  const Activity({
    this.smallText = '',
    this.largeText = '',
    this.details = '',
    this.state = '',
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    smallText: json['small_text'] as String? ?? '',
    largeText: json['large_text'] as String? ?? '',
    details: json['details'] as String? ?? '',
    state: json['state'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'small_text': smallText,
    'large_text': largeText,
    'details': details,
    'state': state,
  };

  bool get hasActivity => details.isNotEmpty || state.isNotEmpty;
}

class UserBrief {
  final String id;
  final String username;
  final String domain;
  String profilePicURL = "";
  final Presence? presence;

  UserBrief({
    required this.id,
    required this.username,
    required this.domain,
    this.profilePicURL = "",
    this.presence,
  });

  factory UserBrief.fromJson(Map<String, dynamic> json) => UserBrief(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
    profilePicURL: json['profilePicURL'] ?? '',
    presence: json['presence'] != null
        ? Presence.fromJson(json['presence'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'domain': domain,
  };

  String get displayName => '$username.$domain';

  bool get isOnline => presence?.isOnline ?? false;
  bool get isOffline => presence?.isOffline ?? true;
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
    receiver: UserBrief.fromJson(
      json['receiver'] as Map<String, dynamic>? ?? {},
    ),
    status: json['status'] as int? ?? 0,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
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
    participants:
        (json['participants'] as List<dynamic>?)
            ?.map((e) => UserBrief.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    lastReadAt: json['last_read_at'] != null
        ? DateTime.tryParse(json['last_read_at'] as String)
        : null,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
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
    joinedAt:
        DateTime.tryParse(json['joined_at'] as String? ?? '') ?? DateTime.now(),
  );
}

/*
{
  "data": [
    {
      "id": "uuid",
      "content": "message text",
      "attachments": "json string",
      "author": {
        "id": "uuid",
        "username": "username",
        "domain": "domain.com"
      },
      "reply_to_id": "uuid or null",
      "created_at": "timestamp",
      "edited_at": "timestamp or null"
    }
  ],
  "success": true
}
*/

class DirectMessage {
  final String id;
  final String content;
  final List<String> attachments;
  final UserBrief author;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime? editedAt;

  const DirectMessage({
    required this.id,
    required this.content,
    required this.attachments,
    required this.author,
    this.replyToId,
    required this.createdAt,
    this.editedAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      attachments: _parseAttachments(json['attachments']),
      author: UserBrief.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
      replyToId: json['reply_to_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'] as String)
          : null,
    );
  }

  static List<String> _parseAttachments(dynamic value) {
    if (value == null || value == '' || value == 'null') return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    // its a JSON string from the backend
    return [];
  }
}
