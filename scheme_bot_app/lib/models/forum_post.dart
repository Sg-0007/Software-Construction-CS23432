class ForumPost {
  final String id;
  final String userId;
  final String title;
  final String content;
  final int likesCount;
  final DateTime createdAt;

  ForumPost({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.likesCount = 0,
    required this.createdAt,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'likes_count': likesCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
