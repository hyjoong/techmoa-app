class Bookmark {
  const Bookmark({
    required this.id,
    required this.title,
    required this.externalUrl,
    this.author,
    this.thumbnailUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String externalUrl;
  final String? author;
  final String? thumbnailUrl;
  final String? publishedAt;

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim();
    final title = json['title']?.toString().trim();
    final externalUrl = json['external_url']?.toString().trim();

    if (id == null ||
        id.isEmpty ||
        title == null ||
        title.isEmpty ||
        externalUrl == null ||
        externalUrl.isEmpty) {
      throw const FormatException('Invalid bookmark payload');
    }

    return Bookmark(
      id: id,
      title: title,
      externalUrl: externalUrl,
      author: json['author']?.toString().trim(),
      thumbnailUrl: json['thumbnail_url']?.toString().trim(),
      publishedAt: json['published_at']?.toString().trim(),
    );
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      title: map['title'] as String,
      externalUrl: map['external_url'] as String,
      author: map['author'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      publishedAt: map['published_at'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'external_url': externalUrl,
      'author': author,
      'thumbnail_url': thumbnailUrl,
      'published_at': publishedAt,
    };
  }
}
