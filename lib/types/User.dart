import 'package:hindsightchat/types/Activity.dart';

class User {
  String id;
  String username;
  String email;
  String domain;
  String? profilePicURL;
  Activity? activity;

  User({
    this.id = "",
    this.username = "",
    this.email = "",
    this.domain = "",
    this.profilePicURL = "",
    this.activity,
  });

  void fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? "";
    username = json['username'] ?? "";
    email = json['email'] ?? "";
    domain = json['domain'] ?? "";
    if (json['activity'] != null) {
      activity = Activity();
      activity!.fromJson(json['activity']);
    }
    profilePicURL = json['profilePicURL'] ?? "";
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'domain': domain,
      'activity': activity?.toJson(),
      'profilePicURL': profilePicURL,
    };
  }
}
