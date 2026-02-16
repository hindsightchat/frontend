import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hindsightchat/api_helper/friends_api.dart';
import 'package:hindsightchat/api_helper/users_api.dart';
import 'package:hindsightchat/api_helper/conversations_api.dart';
import 'package:hindsightchat/api_helper/ApiHelper.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:hindsightchat/types/websocket/websocket-types.dart';
import 'package:hindsightchat/services/ipc_service.dart'
    if (dart.library.js_interop) 'package:hindsightchat/services/ipc_service_stub.dart';
import 'package:hindsightchat/services/rpc_process_manager.dart'
    if (dart.library.js_interop) 'package:hindsightchat/services/rpc_process_manager_stub.dart';

class DataProvider extends ChangeNotifier {
  final Map<String, Friendship> _friends = {};
  final Map<String, FriendRequest> _incomingRequests = {};
  final Map<String, FriendRequest> _outgoingRequests = {};
  final Map<String, Conversation> _conversations = {};
  final Map<String, Server> _servers = {};

  // centralized user cache - tracks all users we interact with (friends, group members, server members)
  // receives presence updates for anyone in our conversations/servers
  final Map<String, UserBrief> _users = {};

  // msgs per conversation
  final Map<String, List<DirectMessage>> _messages = {};

  // conversations with unread messages
  // TODO: refactor to track unread message IDs instead of just conversation IDs for more granular control
  final Set<String> _unreadConversations = {};

  // typing state: conversationId -> Map<userId, expiryTime>
  final Map<String, Map<String, DateTime>> _typingUsers = {};

  IpcServer? _ipcServer;
  RpcProcessManager? _rpcProcess;
  Timer? _activityTimeout;
  static const _activityTimeoutDuration = Duration(minutes: 2);

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _token;
  Activity? _currentActivity;
  String _currentStatus = 'online';

  List<Friendship> get friends => _friends.values.toList();
  List<FriendRequest> get incomingRequests => _incomingRequests.values.toList();
  List<FriendRequest> get outgoingRequests => _outgoingRequests.values.toList();
  List<Conversation> get conversations => _conversations.values.toList();
  List<Server> get servers => _servers.values.toList();
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  Activity? get currentActivity => _currentActivity;
  String get currentStatus => _currentStatus;
  Friendship? getFriend(String id) => _friends[id];
  Friendship? getFriendByUserId(String visibleUserId) => _friends.values
      .where((f) => f.visibleUserId == visibleUserId)
      .firstOrNull;
  Conversation? getConversation(String id) => _conversations[id];
  Server? getServer(String id) => _servers[id];
  UserBrief? getUser(String id) => _users[id];

  // get the user data for a friendship (from users cache)
  UserBrief? getFriendUser(Friendship friendship) =>
      _users[friendship.visibleUserId];

  List<DirectMessage> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];
  bool hasUnread(String conversationId) =>
      _unreadConversations.contains(conversationId);
  Set<String> get unreadConversations => _unreadConversations;

  // get list of user IDs currently typing in a conversation (excludes expired)
  List<String> getTypingUsers(String conversationId) {
    final typing = _typingUsers[conversationId];
    if (typing == null) return [];

    final now = DateTime.now();
    return typing.entries
        .where((e) => e.value.isAfter(now))
        .map((e) => e.key)
        .toList();
  }

  FriendsApi get _friendsApi => FriendsApi(ApiHelper(token: _token));
  UsersApi get _usersApi => UsersApi(ApiHelper(token: _token));
  ConversationsApi get _conversationsApi =>
      ConversationsApi(ApiHelper(token: _token));

  // helper to add/update user in cache (preserves existing presence if not provided)
  void _cacheUser(UserBrief user) {
    final existing = _users[user.id];
    if (existing != null && user.presence == null) {
      // preserve existing presence if new user doesn't have one
      _users[user.id] = UserBrief(
        id: user.id,
        username: user.username,
        domain: user.domain,
        profilePicURL: user.profilePicURL,
        presence: existing.presence,
      );
    } else {
      _users[user.id] = user;
    }
  }

  Future<void> init(String token) async {
    if (_isInitialized) return;
    _token = token;
    _isLoading = true;
    notifyListeners();

    _subscribeToWebSocket();
    _setupIPC();

    await Future.wait([
      _loadFriends(),
      _loadIncomingRequests(),
      _loadOutgoingRequests(),
      _loadConversations(),
      _loadServers(),
    ]);

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _setupIPC() async {
    if (kIsWeb) return;

    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return;
    }

    _ipcServer = IpcServer();
    await _ipcServer!.start();
    _ipcServer!.onMessage(_handleIpcMessage);

    _rpcProcess = RpcProcessManager();
    await _rpcProcess!.start();
  }

  void _handleIpcMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'activity_update':
        final activityData = data['activity'] as Map<String, dynamic>?;
        if (activityData != null) {
          final newActivity = Activity(
            details: activityData['details'] as String? ?? '',
            state: activityData['state'] as String? ?? '',
            largeText: activityData['large_text'] as String? ?? '',
            smallText: activityData['small_text'] as String? ?? '',
            AppName: activityData['app_name'] as String? ?? '',
          );

          _resetActivityTimeout();

          if (_currentActivity != null &&
              _currentActivity!.toJson().toString() ==
                  newActivity.toJson().toString()) {
            return;
          }

          _currentActivity = newActivity;
          ws.updatePresence(_currentStatus, activity: _currentActivity!);
          notifyListeners();
        }
        break;
      case 'activity_clear':
        _clearActivity();
        break;
    }
  }

  void _resetActivityTimeout() {
    _activityTimeout?.cancel();
    _activityTimeout = Timer(_activityTimeoutDuration, _clearActivity);
  }

  void _clearActivity() {
    _activityTimeout?.cancel();
    _activityTimeout = null;
    if (_currentActivity != null) {
      _currentActivity = null;
      ws.updatePresence(_currentStatus);
      notifyListeners();
    }
  }

  StreamSubscription<Map<String, dynamic>>? _readySubscription;

  void _subscribeToWebSocket() {
    // listen to READY event for initial user data
    _readySubscription = ws.readyStream.listen(_onReady);

    ws.on(EventType.friendRequestCreate, _onFriendRequestCreate);
    ws.on(EventType.friendRequestAccepted, _onFriendRequestAccepted);
    ws.on(EventType.friendRemove, _onFriendRemove);
    ws.on(EventType.dmCreate, _onDmCreate);
    ws.on(EventType.dmParticipantAdd, _onDmParticipantAdd);
    ws.on(EventType.dmParticipantLeft, _onDmParticipantLeft);
    ws.on(EventType.serverMemberAdd, _onServerJoin);
    ws.on(EventType.serverMemberRemove, _onServerLeave);
    ws.on(EventType.serverUpdate, _onServerUpdate);
    ws.on(EventType.userUpdate, _onUserUpdate);
    ws.on(EventType.dmMessageCreate, _onDmMessageCreate);
    ws.on(EventType.dmMessageNotify, _onDmMessageNotify);
    ws.on(EventType.presenceUpdate, _onPresenceUpdate);
    ws.on(EventType.typingStart, _onTypingStart);
    ws.on(EventType.typingStop, _onTypingStop);
  }

  void _unsubscribeFromWebSocket() {
    _readySubscription?.cancel();
    _readySubscription = null;

    ws.off(EventType.friendRequestCreate, _onFriendRequestCreate);
    ws.off(EventType.friendRequestAccepted, _onFriendRequestAccepted);
    ws.off(EventType.friendRemove, _onFriendRemove);
    ws.off(EventType.dmCreate, _onDmCreate);
    ws.off(EventType.dmParticipantAdd, _onDmParticipantAdd);
    ws.off(EventType.dmParticipantLeft, _onDmParticipantLeft);
    ws.off(EventType.serverMemberAdd, _onServerJoin);
    ws.off(EventType.serverMemberRemove, _onServerLeave);
    ws.off(EventType.serverUpdate, _onServerUpdate);
    ws.off(EventType.userUpdate, _onUserUpdate);
    ws.off(EventType.dmMessageCreate, _onDmMessageCreate);
    ws.off(EventType.dmMessageNotify, _onDmMessageNotify);
    ws.off(EventType.presenceUpdate, _onPresenceUpdate);
    ws.off(EventType.typingStart, _onTypingStart);
    ws.off(EventType.typingStop, _onTypingStop);
  }

  void _onReady(Map<String, dynamic> data) {
    // get saved status from READY payload
    final status = data['status'] as String?;
    if (status != null && status.isNotEmpty) {
      _currentStatus = status;
    } else {
      // reset to default of online
      _currentStatus = 'online';
    }

    // populate users cache from READY payload
    final usersList = data['users'] as List<dynamic>?;
    if (usersList != null) {
      for (final userData in usersList) {
        final userMap = userData as Map<String, dynamic>;
        final presenceData = userMap['presence'] as Map<String, dynamic>?;

        Presence? presence;
        if (presenceData != null) {
          final activityData =
              presenceData['activity'] as Map<String, dynamic>?;
          presence = Presence(
            status: presenceData['status'] as String? ?? 'offline',
            activity: activityData != null
                ? Activity.fromJson(activityData)
                : null,
            updatedAt: presenceData['updated_at'] as int? ?? 0,
          );
        }

        final user = UserBrief(
          id: userMap['id'] as String? ?? '',
          username: userMap['username'] as String? ?? '',
          domain: userMap['domain'] as String? ?? '',
          profilePicURL: userMap['profilePicURL'] as String? ?? '',
          presence: presence,
        );

        _users[user.id] = user;
      }
    }
    _notifyAndScheduleFrame();
  }

  // update status (online, idle, dnd, offline)
  // contacts webhook and saves
  void updateStatus(String status) {
    if (!['online', 'idle', 'dnd', 'offline'].contains(status)) return;

    _currentStatus = status;
    ws.updatePresence(status, activity: _currentActivity);
    notifyListeners();
  }

  // loads friends for init
  Future<void> _loadFriends() async {
    final response = await _friendsApi.getFriends();
    if (response.isSuccess && response.data != null) {
      _friends.clear();
      for (final f in response.data!) {
        _friends[f.id] = f;
      }
    }
  }

  Future<void> _loadIncomingRequests() async {
    final response = await _friendsApi.getPendingRequests();
    if (response.isSuccess && response.data != null) {
      _incomingRequests.clear();
      for (final r in response.data!) {
        _incomingRequests[r.id] = r;
      }
    }
  }

  Future<void> _loadOutgoingRequests() async {
    final response = await _friendsApi.getOutgoingRequests();
    if (response.isSuccess && response.data != null) {
      _outgoingRequests.clear();
      for (final r in response.data!) {
        _outgoingRequests[r.id] = r;
      }
    }
  }

  Future<void> _loadConversations() async {
    final response = await _usersApi.getConversations();
    if (response.isSuccess && response.data != null) {
      _conversations.clear();
      for (final c in response.data!) {
        _conversations[c.id] = c;
        // cache all participants
        for (final p in c.participants) {
          _cacheUser(p);
        }
      }
    }
  }

  Future<void> _loadServers() async {
    final response = await _usersApi.getServers();
    if (response.isSuccess && response.data != null) {
      _servers.clear();
      for (final s in response.data!) {
        _servers[s.id] = s;
      }
    }
  }

  Future<List<DirectMessage>> loadMessages(
    String conversationId, {
    int? limit,
    String? before,
    String? after,
    String? around,
  }) async {
    final response = await _conversationsApi.getMessages(
      conversationId,
      limit: limit,
      before: before,
      after: after,
      around: around,
    );

    if (response.isSuccess && response.data != null) {
      if (before == null && after == null && around == null) {
        // init load - replace messages
        _messages[conversationId] = response.data!;
      } else if (before != null) {
        // loading older messages - prepend
        final existing = _messages[conversationId] ?? [];
        _messages[conversationId] = [...response.data!, ...existing];
      } else if (after != null) {
        // loading newer messages - append
        final existing = _messages[conversationId] ?? [];
        _messages[conversationId] = [...existing, ...response.data!];
      }
      notifyListeners();
      return response.data!;
    }

    return [];
  }

  void markConversationRead(String conversationId) {
    if (_unreadConversations.remove(conversationId)) {
      notifyListeners();
    }
  }

  void addMessage(String conversationId, DirectMessage message) {
    final messages = _messages[conversationId] ?? [];
    // check if message already exists
    if (!messages.any((m) => m.id == message.id)) {
      _messages[conversationId] = [...messages, message];
      _notifyAndScheduleFrame();
    }
  }

  // notifies listeners and forces a frame to be scheduled
  // needed for desktop apps that don't repaint when idle/unfocused
  void _notifyAndScheduleFrame() {
    notifyListeners();
    // force schedule frame to ensure UI updates even when app is unfocused (e.g. for presence updates)
    WidgetsBinding.instance.scheduleFrame();
  }

  void _onFriendRequestCreate(Map<String, dynamic> data) {
    final request = FriendRequest.fromJson(data);
    _incomingRequests[request.id] = request;
    _notifyAndScheduleFrame();
  }

  void _onFriendRequestAccepted(Map<String, dynamic> data) {
    final friendshipId = data['friendship_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    final userData = data['user'] as Map<String, dynamic>?;

    if (friendshipId != null && userData != null) {
      final user = UserBrief.fromJson(userData);

      // cache the user
      _cacheUser(user);

      final friendship = Friendship(
        id: friendshipId,
        visibleUserId: user.id,
        visibleUsername: user.username,
        conversationId: conversationId ?? '',
        since: DateTime.now(),
      );
      _friends[friendshipId] = friendship;

      _outgoingRequests.removeWhere((_, r) => r.receiver.id == user.id);
      _incomingRequests.removeWhere((_, r) => r.sender.id == user.id);

      _notifyAndScheduleFrame();
    }
  }

  void _onFriendRemove(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId != null) {
      _friends.removeWhere((_, f) => f.visibleUserId == userId);
      _notifyAndScheduleFrame();
    }
  }

  void _onDmCreate(Map<String, dynamic> data) {
    _loadConversations().then((_) => _notifyAndScheduleFrame());
  }

  void _onDmParticipantAdd(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != null) {
      _loadConversations().then((_) => _notifyAndScheduleFrame());
    }
  }

  void _onDmParticipantLeft(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != null) {
      _loadConversations().then((_) => _notifyAndScheduleFrame());
    }
  }

  void _onServerJoin(Map<String, dynamic> data) {
    _loadServers().then((_) => _notifyAndScheduleFrame());
  }

  void _onServerLeave(Map<String, dynamic> data) {
    final serverId = data['server_id'] as String?;
    if (serverId != null) {
      _servers.remove(serverId);
      _notifyAndScheduleFrame();
    }
  }

  void _onServerUpdate(Map<String, dynamic> data) {
    _loadServers().then((_) => _notifyAndScheduleFrame());
  }

  void _onUserUpdate(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    final fields = data['fields'] as Map<String, dynamic>?;
    if (userId == null || fields == null) return;

    // update users cache
    final existingUser = _users[userId];
    if (existingUser != null) {
      _users[userId] = UserBrief(
        id: existingUser.id,
        username: fields['username'] as String? ?? existingUser.username,
        domain: fields['domain'] as String? ?? existingUser.domain,
        profilePicURL:
            fields['profilePicURL'] as String? ?? existingUser.profilePicURL,
        presence: existingUser.presence,
      );
      _notifyAndScheduleFrame();
    }
  }

  void _onDmMessageCreate(Map<String, dynamic> data) {
    // full message received (user has focus on this conversation)
    final conversationId = data['conversation_id'] as String?;
    if (conversationId == null) return;

    final message = DirectMessage.fromJson(data);
    addMessage(conversationId, message);
  }

  void _onDmMessageNotify(Map<String, dynamic> data) {
    // notif only (user doesn't have focus on this conversation)
    final conversationId = data['conversation_id'] as String?;
    if (conversationId == null) return;

    _unreadConversations.add(conversationId);
    _notifyAndScheduleFrame();
  }

  void _onPresenceUpdate(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId == null) return;

    final status = data['status'] as String? ?? 'offline';
    final activityData = data['activity'] as Map<String, dynamic>?;
    final updatedAt = data['updated_at'] as int? ?? 0;

    final newPresence = Presence(
      status: status,
      activity: activityData != null ? Activity.fromJson(activityData) : null,
      updatedAt: updatedAt,
    );

    // update centralized user cache (single source of truth)
    final existingUser = _users[userId];
    if (existingUser != null) {
      _users[userId] = UserBrief(
        id: existingUser.id,
        username: existingUser.username,
        domain: existingUser.domain,
        profilePicURL: existingUser.profilePicURL,
        presence: newPresence,
      );
      _notifyAndScheduleFrame();
    }
  }

  void _onTypingStart(Map<String, dynamic> data) {
    final visibleUserId = data['user_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    if (visibleUserId == null || conversationId == null) return;

    // set typing with 5 second TTL
    _typingUsers.putIfAbsent(conversationId, () => {});
    _typingUsers[conversationId]![visibleUserId] = DateTime.now().add(
      const Duration(seconds: 5),
    );
    _notifyAndScheduleFrame();

    // schedule cleanup after TTL
    Future.delayed(const Duration(seconds: 5), () {
      _cleanupExpiredTyping(conversationId);
    });
  }

  void _onTypingStop(Map<String, dynamic> data) {
    final visibleUserId = data['user_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    if (visibleUserId == null || conversationId == null) return;

    _typingUsers[conversationId]?.remove(visibleUserId);
    _notifyAndScheduleFrame();
  }

  void _cleanupExpiredTyping(String conversationId) {
    final typing = _typingUsers[conversationId];
    if (typing == null) return;

    final now = DateTime.now();
    typing.removeWhere((_, expiry) => expiry.isBefore(now));

    if (typing.isEmpty) {
      _typingUsers.remove(conversationId);
    }

    _notifyAndScheduleFrame();
  }

  // clear typing state when user sends a message
  void clearTyping(String conversationId, String visibleUserId) {
    _typingUsers[conversationId]?.remove(visibleUserId);
    _notifyAndScheduleFrame();
  }

  Future<bool> sendFriendRequest({String? userId, String? username}) async {
    final response = await _friendsApi.sendRequest(
      userId: userId,
      username: username,
    );
    if (response.isSuccess && response.data != null) {
      _outgoingRequests[response.data!.id] = response.data!;
      notifyListeners();
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> acceptFriendRequest(String requestId) async {
    final response = await _friendsApi.acceptRequest(requestId);
    if (response.isSuccess && response.data != null) {
      _friends[response.data!.id] = response.data!;
      _incomingRequests.remove(requestId);
      notifyListeners();
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> declineFriendRequest(String requestId) async {
    final response = await _friendsApi.declineRequest(requestId);
    if (response.isSuccess) {
      _incomingRequests.remove(requestId);
      notifyListeners();
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> cancelFriendRequest(String requestId) async {
    final response = await _friendsApi.cancelRequest(requestId);
    if (response.isSuccess) {
      _outgoingRequests.remove(requestId);
      notifyListeners();
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  Future<bool> removeFriend(String visibleUserId) async {
    final response = await _friendsApi.removeFriend(visibleUserId);
    if (response.isSuccess) {
      _friends.removeWhere((_, f) => f.visibleUserId == visibleUserId);
      notifyListeners();
      return true;
    }
    _error = response.error;
    notifyListeners();
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _unsubscribeFromWebSocket();
    _activityTimeout?.cancel();
    _activityTimeout = null;
    _rpcProcess?.stop();
    _rpcProcess = null;
    _ipcServer?.stop();
    _ipcServer = null;
    _friends.clear();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _conversations.clear();
    _servers.clear();
    _users.clear();
    _messages.clear();
    _unreadConversations.clear();
    _typingUsers.clear();
    _isInitialized = false;
    _isLoading = false;
    _error = null;
    _token = null;
    _currentActivity = null;
    _currentStatus = 'online';
    notifyListeners();
  }

  @override
  void dispose() {
    _unsubscribeFromWebSocket();
    _activityTimeout?.cancel();
    _rpcProcess?.stop();
    _ipcServer?.stop();
    super.dispose();
  }
}
