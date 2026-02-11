class AuthUser {
  final String id;
  final String username;
  final String domain;
  final String email;
  final bool isDomainVerified;
  String profilePicURL = "";
  final String? token;

  AuthUser({
    required this.id,
    required this.username,
    required this.domain,
    required this.email,
    required this.isDomainVerified,
    this.profilePicURL = "",
    this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
    email: json['email'] as String? ?? '',
    isDomainVerified: json['isDomainVerified'] as bool? ?? false,
    token: json['token'] as String?,
    profilePicURL: json['profilePicURL'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'domain': domain,
    'email': email,
    'isDomainVerified': isDomainVerified,
    if (token != null) 'token': token,
    'profilePicURL': profilePicURL,
  };

  AuthUser copyWith({
    String? id,
    String? username,
    String? domain,
    String? email,
    bool? isDomainVerified,
    String? profilePicURL,
    String? token,
  }) => AuthUser(
    id: id ?? this.id,
    username: username ?? this.username,
    domain: domain ?? this.domain,
    email: email ?? this.email,
    isDomainVerified: isDomainVerified ?? this.isDomainVerified,
    token: token ?? this.token,
    profilePicURL: profilePicURL ?? this.profilePicURL,
  );
}
