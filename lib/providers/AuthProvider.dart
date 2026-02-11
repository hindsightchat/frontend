import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hindsightchat/api_helper/auth_api.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/services/websocket_service.dart';
import 'package:hindsightchat/types/api_response.dart';
import 'package:hindsightchat/types/auth_user.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  DataProvider? _dataProvider;

  AuthUser? _user;
  String? _token;
  AuthState _state = AuthState.initial;
  String? _error;

  AuthUser? get user => _user;
  String? get token => _token;
  AuthState get state => _state;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  AuthApi get _authApi => AuthApi.withToken(_token);

  void setDataProvider(DataProvider provider) {
    _dataProvider = provider;
  }

  Future<void> init() async {
    if (_state != AuthState.initial) return;

    _state = AuthState.loading;
    notifyListeners();

    _token = await _storage.read(key: 'token');

    if (_token != null) {
      // check if there is a user in storage and user_timestamp that is less than 2 hours
      final _storeduser = await _storage.read(key: 'user');
      final _storedUserTimestampStr = await _storage.read(
        key: 'user_timestamp',
      );

      if (_storeduser != null && _storedUserTimestampStr != null) {
        final _storedUserTimestamp = DateTime.tryParse(_storedUserTimestampStr);
        if (_storedUserTimestamp != null &&
            DateTime.now().difference(_storedUserTimestamp) <
                const Duration(hours: 2)) {
          final _decodedData = jsonDecode(_storeduser);
          _user = AuthUser.fromJson(_decodedData);
          _state = AuthState.authenticated;
          ws.connect(_token!);
          _dataProvider?.init(_token!);
          notifyListeners();
          return;
        }
      }

      final response = await _authApi.me();
      if (response.isSuccess) {
        _user = response.data;
        _state = AuthState.authenticated;

        // Save user and timestamp to storage
        await _storage.write(key: 'user', value: jsonEncode(_user));
        await _storage.write(
          key: 'user_timestamp',
          value: DateTime.now().toIso8601String(),
        );

        ws.connect(_token!);
        _dataProvider?.init(_token!);
      } else {
        await _clearAuth();
      }
    } else {
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  Future<ApiResponse<AuthUser>> login({
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    final response = await AuthApi.withToken(
      null,
    ).login(email: email, password: password);

    if (response.isSuccess && response.data != null) {
      _user = response.data;
      _token = response.data!.token;
      await _storage.write(key: 'token', value: _token);
      _state = AuthState.authenticated;
      ws.connect(_token!);
      _dataProvider?.init(_token!);
    } else {
      _error = response.error;
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
    return response;
  }

  Future<ApiResponse<AuthUser>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    final response = await AuthApi.withToken(
      null,
    ).register(username: username, email: email, password: password);

    if (response.isSuccess && response.data != null) {
      _user = response.data;
      _token = response.data!.token;
      await _storage.write(key: 'token', value: _token);
      _state = AuthState.authenticated;
      ws.connect(_token!);
      _dataProvider?.init(_token!);
    } else {
      _error = response.error;
      _state = AuthState.unauthenticated;
    }

    notifyListeners();
    return response;
  }

  Future<ApiResponse<AuthUser>> refreshUser() async {
    if (_token == null) {
      return ApiResponse(
        success: false,
        error: 'Not authenticated',
        statusCode: 401,
      );
    }

    final response = await _authApi.me();

    if (response.isSuccess) {
      _user = response.data;
      notifyListeners();
    }

    return response;
  }

  Future<void> logout() async {
    ws.disconnect();
    _dataProvider?.clear();
    await _clearAuth();
    notifyListeners();
  }

  Future<void> _clearAuth() async {
    _user = null;
    _token = null;
    _error = null;
    _state = AuthState.unauthenticated;
    await _storage.delete(key: 'token');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
