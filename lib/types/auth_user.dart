
class AuthUser {
  final String id;
  final String username;
  final String domain;
  final String email;
  final bool isDomainVerified;
  final String? token;

  const AuthUser({
    required this.id,
    required this.username,
    required this.domain,
    required this.email,
    required this.isDomainVerified,
    this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
    email: json['email'] as String? ?? '',
    isDomainVerified: json['isDomainVerified'] as bool? ?? false,
    token: json['token'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'domain': domain,
    'email': email,
    'isDomainVerified': isDomainVerified,
    if (token != null) 'token': token,
  };

  AuthUser copyWith({
    String? id,
    String? username,
    String? domain,
    String? email,
    bool? isDomainVerified,
    String? token,
  }) => AuthUser(
    id: id ?? this.id,
    username: username ?? this.username,
    domain: domain ?? this.domain,
    email: email ?? this.email,
    isDomainVerified: isDomainVerified ?? this.isDomainVerified,
    token: token ?? this.token,
  );
}
