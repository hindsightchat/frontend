class Activity {
  String smallText = "";
  String largeText = "";
  String details = "";
  String state = "";

  Activity({
    this.smallText = "",
    this.largeText = "",
    this.details = "",
    this.state = "",
  });

  void fromJson(Map<String, dynamic> json) {
    smallText = json['small_text'] ?? "";
    largeText = json['large_text'] ?? "";
    details = json['details'] ?? "";
    state = json['state'] ?? "";
  }

  // to json
  Map<String, dynamic> toJson() {
    return {
      'small_text': smallText,
      'large_text': largeText,
      'details': details,
      'state': state,
    };
  }
}
