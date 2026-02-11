import 'package:hindsightchat/api_helper/ApiHelper.dart';
import 'package:hindsightchat/types/api_response.dart';
import 'package:hindsightchat/types/models.dart';

class UsersApi {
  final ApiHelper _api;

  UsersApi(this._api);
  factory UsersApi.withToken(String? token) => UsersApi(ApiHelper(token: token));

  Future<ApiResponse<List<Conversation>>> getConversations() async {
    final response = await _api.get<List<dynamic>>('/users/@me/conversations');
    if (response.isSuccess && response.data != null) {
      final conversations = response.data!
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(success: true, data: conversations, statusCode: response.statusCode);
    }
    return ApiResponse(success: false, error: response.error, statusCode: response.statusCode);
  }

  Future<ApiResponse<List<Server>>> getServers() async {
    final response = await _api.get<List<dynamic>>('/users/@me/servers');
    if (response.isSuccess && response.data != null) {
      final servers = response.data!
          .map((e) => Server.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(success: true, data: servers, statusCode: response.statusCode);
    }
    return ApiResponse(success: false, error: response.error, statusCode: response.statusCode);
  }
}
