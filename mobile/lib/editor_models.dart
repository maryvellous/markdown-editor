enum EditorMode { edit, preview, split }

class RecentDocument {
  const RecentDocument({
    required this.name,
    required this.content,
    required this.openedAt,
    this.uri,
  });

  final String name;
  final String content;
  final String openedAt;
  final String? uri;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'content': content,
        'openedAt': openedAt,
        'uri': uri,
      };

  factory RecentDocument.fromJson(Map<String, dynamic> json) {
    return RecentDocument(
      name: json['name'] as String? ?? 'documento.md',
      content: json['content'] as String? ?? '',
      openedAt: json['openedAt'] as String? ?? '',
      uri: (json['uri'] as String?)?.trim().isEmpty == true
          ? null
          : json['uri'] as String?,
    );
  }
}
