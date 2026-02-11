import 'package:hindsightchat/api_helper/ApiHelper.dart';
import 'package:hindsightchat/types/api_response.dart';
import 'package:hindsightchat/types/auth_user.dart';

class AuthApi {
  final ApiHelper _api;

  AuthApi(this._api);

  // create authapi w/ token
  factory AuthApi.withToken(String? token) => AuthApi(ApiHelper(token: token));

  // login with email & password
  Future<ApiResponse<AuthUser>> login({
    required String email,
    required String password,
  }) {
    return _api.post<AuthUser>(
      '/auth/login',
      body: {'email': email, 'password': password},
      fromJson: AuthUser.fromJson,
    );
  }

  // register with username, email & password
  Future<ApiResponse<AuthUser>> register({
    required String username,
    required String email,
    required String password,
  }) {
    return _api.post<AuthUser>(
      '/auth/register',
      body: {'username': username, 'email': email, 'password': password},
      fromJson: AuthUser.fromJson,
    );
  }

  // get current user info
  Future<ApiResponse<AuthUser>> me() {
    return _api.get<AuthUser>('/auth/me', fromJson: AuthUser.fromJson);
  }
}
