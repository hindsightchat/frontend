import 'package:hindsightchat/api_helper/ApiHelper.dart';
import 'package:hindsightchat/types/api_response.dart';
import 'package:hindsightchat/types/models.dart';

class FriendsApi {
  final ApiHelper _api;

  FriendsApi(this._api);
  factory FriendsApi.withToken(String? token) => FriendsApi(ApiHelper(token: token));

  Future<ApiResponse<List<Friendship>>> getFriends() async {
    final response = await _api.get<List<dynamic>>('/friends');
    if (response.isSuccess && response.data != null) {
      final friends = response.data!
          .map((e) => Friendship.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(success: true, data: friends, statusCode: response.statusCode);
    }
    return ApiResponse(success: false, error: response.error, statusCode: response.statusCode);
  }

  Future<ApiResponse<List<FriendRequest>>> getPendingRequests() async {
    final response = await _api.get<List<dynamic>>('/friends/requests');
    if (response.isSuccess && response.data != null) {
      final requests = response.data!
          .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(success: true, data: requests, statusCode: response.statusCode);
    }
    return ApiResponse(success: false, error: response.error, statusCode: response.statusCode);
  }

  Future<ApiResponse<List<FriendRequest>>> getOutgoingRequests() async {
    final response = await _api.get<List<dynamic>>('/friends/requests/outgoing');
    if (response.isSuccess && response.data != null) {
      final requests = response.data!
          .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(success: true, data: requests, statusCode: response.statusCode);
    }
    return ApiResponse(success: false, error: response.error, statusCode: response.statusCode);
  }

  Future<ApiResponse<FriendRequest>> sendRequest({String? userId, String? username}) {
    return _api.post<FriendRequest>(
      '/friends/requests',
      body: {
        if (userId != null) 'user_id': userId,
        if (username != null) 'username': username,
      },
      fromJson: FriendRequest.fromJson,
    );
  }

  Future<ApiResponse<Friendship>> acceptRequest(String requestId) {
    return _api.post<Friendship>(
      '/friends/requests/$requestId/accept',
      fromJson: Friendship.fromJson,
    );
  }

  Future<ApiResponse<void>> declineRequest(String requestId) {
    return _api.post('/friends/requests/$requestId/decline');
  }

  Future<ApiResponse<void>> cancelRequest(String requestId) {
    return _api.delete('/friends/requests/$requestId');
  }

  Future<ApiResponse<void>> removeFriend(String friendId) {
    return _api.delete('/friends/$friendId');
  }
}
