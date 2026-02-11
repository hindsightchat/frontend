import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hindsightchat/types/api_response.dart';

class ApiHelper {
  final String? token;
  final String baseUrl;

  static const String _defaultBaseUrl = kDebugMode
      ? 'http://localhost:3000'
      : 'https://api.hindsight.chat';

  ApiHelper({this.token, String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }
    return uri;
  }

  Future<ApiResponse<T>> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic> json)? fromJson,
  ) async {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final success = body['success'] as bool? ?? false;

      if (success && response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        return ApiResponse<T>(
          success: true,
          data: fromJson != null && data != null ? fromJson(data) : data as T?,
          statusCode: response.statusCode,
        );
      }

      return ApiResponse<T>(
        success: false,
        error: body['error'] as String? ?? 'Unknown error',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: 'Failed to parse response: $e',
        statusCode: response.statusCode,
      );
    }
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    T Function(Map<String, dynamic> json)? fromJson,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await http.get(_buildUri(path, queryParams), headers: _headers);
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(success: false, error: 'Network error: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    T Function(Map<String, dynamic> json)? fromJson,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await http.post(
        _buildUri(path, queryParams),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(success: false, error: 'Network error: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    T Function(Map<String, dynamic> json)? fromJson,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await http.put(
        _buildUri(path, queryParams),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(success: false, error: 'Network error: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    T Function(Map<String, dynamic> json)? fromJson,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await http.delete(_buildUri(path, queryParams), headers: _headers);
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(success: false, error: 'Network error: $e', statusCode: 0);
    }
  }
}
