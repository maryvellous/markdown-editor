export function createMarkdownGuide({ editor, markdownGuide, getMode, setMode, commitHistory, schedulePreview }) {
  const TICK = String.fromCharCode(96);
  const FENCE = TICK.repeat(3);

  const GUIDE_ITEMS = [
    { label: 'Titolo', syntax: '# … ######', type: 'prefix', value: '# ', placeholder: 'Titolo' },
    { label: 'Grassetto', syntax: '**testo**', type: 'wrap', before: '**', after: '**', placeholder: 'testo' },
    { label: 'Corsivo', syntax: '*testo*', type: 'wrap', before: '*', after: '*', placeholder: 'testo' },
    { label: 'Grassetto + corsivo', syntax: '***testo***', type: 'wrap', before: '***', after: '***', placeholder: 'testo' },
    { label: 'Barrato', syntax: '~~testo~~', type: 'wrap', before: '~~', after: '~~', placeholder: 'testo' },
    { label: 'Codice inline', syntax: TICK + 'codice' + TICK, type: 'wrap', before: TICK, after: TICK, placeholder: 'codice' },
    { label: 'Blocco codice', syntax: FENCE, type: 'snippet', value: FENCE + '\nlinguaggio\ncodice\n' + FENCE, selectText: 'codice' },
    { label: 'Diagramma Mermaid', syntax: FENCE + 'mermaid', type: 'snippet', value: FENCE + 'mermaid\ngraph TD\n  A[Inizio] --> B[Fine]\n' + FENCE, selectText: 'graph TD\n  A[Inizio] --> B[Fine]' },
    { label: 'Citazione', syntax: '> testo', type: 'prefix', value: '> ', placeholder: 'testo' },
    { label: 'Elenco puntato', syntax: '- voce', type: 'prefix', value: '- ', placeholder: 'voce' },
    { label: 'Elenco numerato', syntax: '1. voce', type: 'prefix', value: '1. ', placeholder: 'voce' },
    { label: 'Checkbox', syntax: '- [ ] attività', type: 'prefix', value: '- [ ] ', placeholder: 'attività' },
    { label: 'Link', syntax: '[testo](url)', type: 'snippet', value: '[testo](https://)', selectText: 'testo' },
    { label: 'Immagine', syntax: '![alt](file.png)', type: 'snippet', value: '![descrizione](immagine.png)', selectText: 'descrizione' },
    { label: 'Separatore', syntax: '---', type: 'snippet', value: '\n---\n' },
    { label: 'Tabella', syntax: '| A | B |', type: 'snippet', value: '| Colonna A | Colonna B |\n| --- | --- |\n| Valore | Valore |' },
    { label: 'Nota a piè pagina', syntax: '[^1]', type: 'snippet', value: 'Testo[^1]\n\n[^1]: Nota', selectText: 'Nota' },
    { label: 'A capo forzato', syntax: '2 spazi + Invio', type: 'snippet', value: '  \n' },
    { label: 'Escape', syntax: '\\*testo\\*', type: 'snippet', value: '\\*testo\\*', selectText: 'testo' },
  ];

  function renderGuide() {
    markdownGuide.replaceChildren();

    GUIDE_ITEMS.forEach((item) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'guide-item';
      button.title = 'Inserisci: ' + item.label;

      const label = document.createElement('span');
      label.className = 'guide-label';
      label.textContent = item.label;

      const syntax = document.createElement('code');
      syntax.className = 'guide-syntax';
      syntax.textContent = item.syntax;

      button.append(label, syntax);
      button.addEventListener('click', () => insertGuideItem(item));
      markdownGuide.appendChild(button);
    });
  }

  function insertGuideItem(item) {
    if (getMode() === 'preview') setMode('split');
    editor.focus();

    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    const selected = editor.value.slice(start, end);
    let insertion = '';
    let selectionStart = null;
    let selectionEnd = null;

    if (item.type === 'wrap') {
      const body = selected || item.placeholder || 'testo';
      insertion = item.before + body + item.after;
      if (!selected) {
        selectionStart = start + item.before.length;
        selectionEnd = selectionStart + body.length;
      }
    } else if (item.type === 'prefix') {
      if (selected) {
        insertion = selected
          .split('\n')
          .map((line) => item.value + line)
          .join('\n');
      } else {
        const body = item.placeholder || 'testo';
        insertion = item.value + body;
        selectionStart = start + item.value.length;
        selectionEnd = selectionStart + body.length;
      }
    } else {
      insertion = item.value || '';
      if (item.selectText) {
        const offset = insertion.indexOf(item.selectText);
        if (offset >= 0) {
          selectionStart = start + offset;
          selectionEnd = selectionStart + item.selectText.length;
        }
      }
    }

    editor.setRangeText(insertion, start, end, 'end');

    if (selectionStart !== null && selectionEnd !== null) {
      editor.setSelectionRange(selectionStart, selectionEnd);
    }

    commitHistory('guide');
    schedulePreview();
  }

  return { renderGuide };
}
