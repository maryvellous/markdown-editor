import 'package:flutter/services.dart';

enum GuideKind { wrap, prefix, snippet }

class GuideItem {
  const GuideItem({
    required this.label,
    required this.syntax,
    required this.kind,
    this.before = '',
    this.after = '',
    this.value = '',
    this.placeholder = 'testo',
    this.selectText,
  });

  final String label;
  final String syntax;
  final GuideKind kind;
  final String before;
  final String after;
  final String value;
  final String placeholder;
  final String? selectText;
}

const markdownGuide = <GuideItem>[
  GuideItem(
    label: 'Titolo',
    syntax: '# Titolo',
    kind: GuideKind.prefix,
    value: '# ',
    placeholder: 'Titolo',
  ),
  GuideItem(
    label: 'Grassetto',
    syntax: '**testo**',
    kind: GuideKind.wrap,
    before: '**',
    after: '**',
  ),
  GuideItem(
    label: 'Corsivo',
    syntax: '*testo*',
    kind: GuideKind.wrap,
    before: '*',
    after: '*',
  ),
  GuideItem(
    label: 'Barrato',
    syntax: '~~testo~~',
    kind: GuideKind.wrap,
    before: '~~',
    after: '~~',
  ),
  GuideItem(
    label: 'Codice inline',
    syntax: '`codice`',
    kind: GuideKind.wrap,
    before: '`',
    after: '`',
    placeholder: 'codice',
  ),
  GuideItem(
    label: 'Citazione',
    syntax: '> testo',
    kind: GuideKind.prefix,
    value: '> ',
  ),
  GuideItem(
    label: 'Elenco',
    syntax: '- voce',
    kind: GuideKind.prefix,
    value: '- ',
    placeholder: 'voce',
  ),
  GuideItem(
    label: 'Elenco numerato',
    syntax: '1. voce',
    kind: GuideKind.prefix,
    value: '1. ',
    placeholder: 'voce',
  ),
  GuideItem(
    label: 'Checkbox',
    syntax: '- [ ] attività',
    kind: GuideKind.prefix,
    value: '- [ ] ',
    placeholder: 'attività',
  ),
  GuideItem(
    label: 'Link',
    syntax: '[testo](url)',
    kind: GuideKind.snippet,
    value: '[testo](https://)',
    selectText: 'testo',
  ),
  GuideItem(
    label: 'Immagine',
    syntax: '![alt](file.png)',
    kind: GuideKind.snippet,
    value: '![descrizione](immagine.png)',
    selectText: 'descrizione',
  ),
  GuideItem(
    label: 'Blocco codice',
    syntax: '```',
    kind: GuideKind.snippet,
    value: '```\nlinguaggio\ncodice\n```',
    selectText: 'codice',
  ),
  GuideItem(
    label: 'Separatore',
    syntax: '---',
    kind: GuideKind.snippet,
    value: '\n---\n',
  ),
  GuideItem(
    label: 'Tabella',
    syntax: '| A | B |',
    kind: GuideKind.snippet,
    value: '| Colonna A | Colonna B |\n| --- | --- |\n| Valore | Valore |',
  ),
  GuideItem(
    label: 'Diagramma Mermaid',
    syntax: '```mermaid',
    kind: GuideKind.snippet,
    value: '```mermaid\ngraph TD\n  A[Inizio] --> B[Fine]\n```',
    selectText: 'graph TD\n  A[Inizio] --> B[Fine]',
  ),
];

TextEditingValue applyGuideItem(TextEditingValue value, GuideItem item) {
  final text = value.text;
  var selection = value.selection;
  if (!selection.isValid) {
    selection = TextSelection.collapsed(offset: text.length);
  }

  final start = selection.start;
  final end = selection.end;
  final selected = text.substring(start, end);
  late final String insertion;
  int? selectStart;
  int? selectEnd;

  switch (item.kind) {
    case GuideKind.wrap:
      final body = selected.isEmpty ? item.placeholder : selected;
      insertion = '${item.before}$body${item.after}';
      if (selected.isEmpty) {
        selectStart = start + item.before.length;
        selectEnd = selectStart + body.length;
      }
      break;
    case GuideKind.prefix:
      if (selected.isNotEmpty) {
        insertion = selected
            .split('\n')
            .map((line) => '${item.value}$line')
            .join('\n');
      } else {
        insertion = '${item.value}${item.placeholder}';
        selectStart = start + item.value.length;
        selectEnd = selectStart + item.placeholder.length;
      }
      break;
    case GuideKind.snippet:
      insertion = item.value;
      if (item.selectText != null) {
        final offset = insertion.indexOf(item.selectText!);
        if (offset >= 0) {
          selectStart = start + offset;
          selectEnd = selectStart + item.selectText!.length;
        }
      }
      break;
  }

  final next = text.replaceRange(start, end, insertion);
  final nextSelection = selectStart != null && selectEnd != null
      ? TextSelection(baseOffset: selectStart, extentOffset: selectEnd)
      : TextSelection.collapsed(offset: start + insertion.length);
  return TextEditingValue(text: next, selection: nextSelection);
}
