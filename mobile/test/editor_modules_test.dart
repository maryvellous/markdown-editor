import 'package:diaspro_markdown_mobile/markdown_guide.dart';
import 'package:diaspro_markdown_mobile/preview_segments.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guide wraps selected text and places cursor after insertion', () {
    const value = TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 6, extentOffset: 11),
    );
    const item = GuideItem(label: 'Bold', syntax: '**', kind: GuideKind.wrap,
      before: '**', after: '**');
    final result = applyGuideItem(value, item);
    expect(result.text, 'hello **world**');
    expect(result.selection, const TextSelection.collapsed(offset: 15));
  });

  test('guide handles missing selection and selects placeholder', () {
    const item = GuideItem(label: 'Title', syntax: '#', kind: GuideKind.prefix,
      value: '# ', placeholder: 'Titolo');
    final result = applyGuideItem(const TextEditingValue(text: 'abc\n'), item);
    expect(result.text, 'abc\n# Titolo');
    expect(result.selection, const TextSelection(baseOffset: 6, extentOffset: 12));
  });

  test('guide prefixes each selected line', () {
    const value = TextEditingValue(text: 'a\nb',
      selection: TextSelection(baseOffset: 0, extentOffset: 3));
    const item = GuideItem(label: 'List', syntax: '-', kind: GuideKind.prefix,
      value: '- ');
    expect(applyGuideItem(value, item).text, '- a\n- b');
  });

  test('guide selects a designated snippet substring', () {
    const item = GuideItem(label: 'Link', syntax: '[]', kind: GuideKind.snippet,
      value: '[text](url)', selectText: 'text');
    final result = applyGuideItem(const TextEditingValue(), item);
    expect(result.text, '[text](url)');
    expect(result.selection, const TextSelection(baseOffset: 1, extentOffset: 5));
  });

  test('preview preserves prose around Mermaid fences including CRLF', () {
    final parts = splitMarkdownPreview('before\n```MERMAID\r\ngraph TD\r\n```\nafter');
    expect(parts.map((part) => part.isMermaid), [false, true, false]);
    expect(parts.map((part) => part.content), ['before\n', 'graph TD', '\nafter']);
  });

  test('preview preserves ordinary code and empty input', () {
    const source = '```dart\nvoid main() {}\n```';
    final parts = splitMarkdownPreview(source);
    expect(parts.single.content, source);
    expect(parts.single.isMermaid, false);
    expect(splitMarkdownPreview(''), isEmpty);
  });
}
