import 'package:hindsightchat/api_helper/ApiHelper.dart';
import 'package:hindsightchat/types/api_response.dart';
import 'package:hindsightchat/types/models.dart';

class ConversationsApi {
  final ApiHelper _api;

  ConversationsApi(this._api);

  // Creates a new group conversation with the specified users
  // [userIds] - list of user IDs to include (excluding the creator)
  // [title] - optional title for the conversation
  Future<ApiResponse<String>> createConversation({
    required List<String> userIds,
    String? title,
  }) async {
    final body = <String, dynamic>{'user_ids': userIds};
    if (title != null && title.isNotEmpty) {
      body['title'] = title;
    }

    final response = await _api.post<Map<String, dynamic>>(
      '/conversation/create',
      body: body,
    );

    if (response.isSuccess && response.data != null) {
      final conversationId = response.data!['conversation_id'] as String?;
      return ApiResponse<String>(
        success: true,
        data: conversationId,
        statusCode: response.statusCode,
      );
    }

    return ApiResponse<String>(
      success: false,
      error: response.error,
      statusCode: response.statusCode,
    );
  }

  Future<ApiResponse<List<DirectMessage>>> getMessages(
    String conversationId, {
    int? limit,
    String? before,
    String? after,
    String? around,
  }) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (before != null) queryParams['before'] = before;
    if (after != null) queryParams['after'] = after;
    if (around != null) queryParams['around'] = around;

    final response = await _api.get<List<dynamic>>(
      '/conversation/$conversationId/messages',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.isSuccess && response.data != null) {
      final messages = (response.data as List<dynamic>)
          .map((e) => DirectMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<DirectMessage>>(
        success: true,
        data: messages,
        statusCode: response.statusCode,
      );
    }

    return ApiResponse<List<DirectMessage>>(
      success: false,
      error: response.error,
      statusCode: response.statusCode,
    );
  }
}
