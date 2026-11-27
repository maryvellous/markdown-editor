class PreviewSegment {
  const PreviewSegment({required this.content, required this.isMermaid});

  final String content;
  final bool isMermaid;
}

final RegExp _mermaidFence = RegExp(
  r'```mermaid[ \t]*\r?\n([\s\S]*?)\r?\n?```',
  caseSensitive: false,
);

List<PreviewSegment> splitMarkdownPreview(String markdown) {
  final result = <PreviewSegment>[];
  var cursor = 0;

  for (final match in _mermaidFence.allMatches(markdown)) {
    if (match.start > cursor) {
      result.add(
        PreviewSegment(
          content: markdown.substring(cursor, match.start),
          isMermaid: false,
        ),
      );
    }
    result.add(
      PreviewSegment(
        content: (match.group(1) ?? '').trim(),
        isMermaid: true,
      ),
    );
    cursor = match.end;
  }

  if (cursor < markdown.length) {
    result.add(
      PreviewSegment(
        content: markdown.substring(cursor),
        isMermaid: false,
      ),
    );
  }

  return result;
}

