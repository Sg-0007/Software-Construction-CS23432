class Scheme {
  final String id;
  final String name;
  final String category;
  final String description;
  final String state;

  Scheme({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.state,
  });

  factory Scheme.fromJson(Map<String, dynamic> json) {
    return Scheme(
      id: json['scheme_id'] ?? '',
      name: json['title'] ?? 'Unknown Scheme',
      category: json['category'] ?? 'General',
      description: json['description'] ?? 'No description provided',
      state: json['state'] ?? 'All States',
    );
  }
}
