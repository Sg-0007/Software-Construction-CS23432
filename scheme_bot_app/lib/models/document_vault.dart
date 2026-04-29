class DocumentVault {
  final String id;
  final String userId;
  final String title;
  final String documentUrl;
  final DateTime uploadedAt;
  final Map<String, dynamic>? extractedData;

  DocumentVault({
    required this.id,
    required this.userId,
    required this.title,
    required this.documentUrl,
    required this.uploadedAt,
    this.extractedData,
  });

  factory DocumentVault.fromJson(Map<String, dynamic> json) {
    return DocumentVault(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      documentUrl: json['document_url'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      extractedData: json['extracted_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'document_url': documentUrl,
      'uploaded_at': uploadedAt.toIso8601String(),
      'extracted_data': extractedData,
    };
  }
}
