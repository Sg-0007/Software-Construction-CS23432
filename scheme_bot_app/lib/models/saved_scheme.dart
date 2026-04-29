class SavedScheme {
  final String id;
  final String userId;
  final String schemeId;
  final DateTime createdAt;

  SavedScheme({
    required this.id,
    required this.userId,
    required this.schemeId,
    required this.createdAt,
  });

  factory SavedScheme.fromJson(Map<String, dynamic> json) {
    return SavedScheme(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      schemeId: json['scheme_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'scheme_id': schemeId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
