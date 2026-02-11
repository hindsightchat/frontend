import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hindsightchat/api_helper/friends_api.dart';
import 'package:hindsightchat/api_helper/users_api.dart';
import 'package:hindsightchat/api_helper/conversations_api.dart';
import 'package:hindsightchat/api_helper/ApiHelper.dart';
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
  
  // msgs per conversation
  final Map<String, List<DirectMessage>> _messages = {};
  
  // conversations with unread messages
  // TODO: refactor to track unread message IDs instead of just conversation IDs for more granular control
  final Set<String> _unreadConversations = {};

  IpcServer? _ipcServer;
  RpcProcessManager? _rpcProcess;
  Timer? _activityTimeout;
  static const _activityTimeoutDuration = Duration(minutes: 2);

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _token;
  Activity? _currentActivity;

  List<Friendship> get friends => _friends.values.toList();
  List<FriendRequest> get incomingRequests => _incomingRequests.values.toList();
  List<FriendRequest> get outgoingRequests => _outgoingRequests.values.toList();
  List<Conversation> get conversations => _conversations.values.toList();
  List<Server> get servers => _servers.values.toList();
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  Activity? get currentActivity => _currentActivity;
  Friendship? getFriend(String id) => _friends[id];
  Friendship? getFriendByUserId(String userId) =>
      _friends.values.where((f) => f.user.id == userId).firstOrNull;
  Conversation? getConversation(String id) => _conversations[id];
  Server? getServer(String id) => _servers[id];
  
  List<DirectMessage> getMessages(String conversationId) => _messages[conversationId] ?? [];
  bool hasUnread(String conversationId) => _unreadConversations.contains(conversationId);
  Set<String> get unreadConversations => _unreadConversations;

  FriendsApi get _friendsApi => FriendsApi(ApiHelper(token: _token));
  UsersApi get _usersApi => UsersApi(ApiHelper(token: _token));
  ConversationsApi get _conversationsApi => ConversationsApi(ApiHelper(token: _token));

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
          );

          _resetActivityTimeout();

          if (_currentActivity != null &&
              _currentActivity!.toJson().toString() ==
                  newActivity.toJson().toString()) {
            return;
          }

          _currentActivity = newActivity;
          ws.updatePresence('online', activity: _currentActivity!);
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
      ws.updatePresence('online');
      notifyListeners();
    }
  }

  void _subscribeToWebSocket() {
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
  }

  void _unsubscribeFromWebSocket() {
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
  }

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
      notifyListeners();
    }
  }

  void _onFriendRequestCreate(Map<String, dynamic> data) {
    final request = FriendRequest.fromJson(data);
    _incomingRequests[request.id] = request;
    notifyListeners();
  }

  void _onFriendRequestAccepted(Map<String, dynamic> data) {
    final friendshipId = data['friendship_id'] as String?;
    final conversationId = data['conversation_id'] as String?;
    final userData = data['user'] as Map<String, dynamic>?;

    if (friendshipId != null && userData != null) {
      final user = UserBrief.fromJson(userData);
      final friendship = Friendship(
        id: friendshipId,
        user: user,
        conversationId: conversationId ?? '',
        since: DateTime.now(),
      );
      _friends[friendshipId] = friendship;

      _outgoingRequests.removeWhere((_, r) => r.receiver.id == user.id);
      _incomingRequests.removeWhere((_, r) => r.sender.id == user.id);

      notifyListeners();
    }
  }

  void _onFriendRemove(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId != null) {
      _friends.removeWhere((_, f) => f.user.id == userId);
      notifyListeners();
    }
  }

  void _onDmCreate(Map<String, dynamic> data) {
    _loadConversations().then((_) => notifyListeners());
  }

  void _onDmParticipantAdd(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != null) {
      _loadConversations().then((_) => notifyListeners());
    }
  }

  void _onDmParticipantLeft(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (convId != null) {
      _loadConversations().then((_) => notifyListeners());
    }
  }

  void _onServerJoin(Map<String, dynamic> data) {
    _loadServers().then((_) => notifyListeners());
  }

  void _onServerLeave(Map<String, dynamic> data) {
    final serverId = data['server_id'] as String?;
    if (serverId != null) {
      _servers.remove(serverId);
      notifyListeners();
    }
  }

  void _onServerUpdate(Map<String, dynamic> data) {
    _loadServers().then((_) => notifyListeners());
  }

  void _onUserUpdate(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    final fields = data['fields'] as Map<String, dynamic>?;
    if (userId == null || fields == null) return;

    var changed = false;

    for (final entry in _friends.entries) {
      if (entry.value.user.id == userId) {
        final oldUser = entry.value.user;
        final newUser = UserBrief(
          id: oldUser.id,
          username: fields['username'] as String? ?? oldUser.username,
          domain: fields['domain'] as String? ?? oldUser.domain,
        );
        _friends[entry.key] = Friendship(
          id: entry.value.id,
          user: newUser,
          conversationId: entry.value.conversationId,
          since: entry.value.since,
        );
        changed = true;
        break;
      }
    }

    if (changed) notifyListeners();
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
    notifyListeners();
  }
  
  void _onPresenceUpdate(Map<String, dynamic> data) {
    final userId = data['user_id'] as String?;
    if (userId == null) return;
    
    final status = data['status'] as String? ?? 'offline';
    final activityData = data['activity'] as Map<String, dynamic>?;
    final updatedAt = data['updated_at'] as int? ?? 0;
    
    // find friend with this user ID and update their presence
    for (final entry in _friends.entries) {
      if (entry.value.user.id == userId) {
        final oldFriend = entry.value;
        final newPresence = Presence(
          status: status,
          activity: activityData != null 
              ? Activity.fromJson(activityData) 
              : null,
          updatedAt: updatedAt,
        );
        
        final newUser = UserBrief(
          id: oldFriend.user.id,
          username: oldFriend.user.username,
          domain: oldFriend.user.domain,
          presence: newPresence,
        );
        
        _friends[entry.key] = Friendship(
          id: oldFriend.id,
          user: newUser,
          conversationId: oldFriend.conversationId,
          since: oldFriend.since,
        );
        
        notifyListeners();
        break;
      }
    }
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

  Future<bool> removeFriend(String friendId) async {
    final response = await _friendsApi.removeFriend(friendId);
    if (response.isSuccess) {
      _friends.removeWhere((_, f) => f.user.id == friendId);
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
    _messages.clear();
    _unreadConversations.clear();
    _isInitialized = false;
    _isLoading = false;
    _error = null;
    _token = null;
    _currentActivity = null;
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
