export function createMermaidRenderer({ preview, isCurrent }) {
  const MERMAID_CACHE_LIMIT = 24;
  const mermaidCache = new Map();
  let mermaidInitialized = false;
  let mermaidRenderSequence = 0;
  function ensureMermaidInitialized() {
    if (mermaidInitialized) return true;
    if (!window.mermaid) return false;

    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: 'base',
      suppressErrorRendering: true,
      themeVariables: {
        primaryColor: '#f4ecd9',
        primaryTextColor: '#2b1c47',
        primaryBorderColor: '#7a3f67',
        lineColor: '#7a3f67',
        secondaryColor: '#e8d19e',
        tertiaryColor: '#a5c4dc',
        background: '#fffdf8',
        mainBkg: '#fffdf8',
        nodeBorder: '#7a3f67',
        clusterBkg: '#f4ecd9',
        clusterBorder: '#9d85c6',
        edgeLabelBackground: '#fffdf8',
        fontFamily: 'Inter, Segoe UI, system-ui, sans-serif',
      },
      flowchart: {
        htmlLabels: false,
        useMaxWidth: true,
      },
    });
    mermaidInitialized = true;
    return true;
  }

  function readCachedMermaid(source) {
    if (!mermaidCache.has(source)) return null;
    const svg = mermaidCache.get(source);
    mermaidCache.delete(source);
    mermaidCache.set(source, svg);
    return svg;
  }

  function cacheMermaid(source, svg) {
    mermaidCache.delete(source);
    mermaidCache.set(source, svg);
    while (mermaidCache.size > MERMAID_CACHE_LIMIT) {
      const firstKey = mermaidCache.keys().next().value;
      mermaidCache.delete(firstKey);
    }
  }

  function buildMermaidBlock(svg, source) {
    const block = document.createElement('section');
    block.className = 'mermaid-block';

    const head = document.createElement('div');
    head.className = 'mermaid-block-head';

    const title = document.createElement('span');
    title.className = 'mermaid-block-title';
    title.textContent = 'Diagramma Mermaid';

    const openButton = document.createElement('button');
    openButton.type = 'button';
    openButton.className = 'mermaid-open-button';
    openButton.textContent = 'Apri grande';
    openButton.title = 'Apri il diagramma nel viewer';
    openButton.dataset.mermaidViewer = 'true';

    const diagram = document.createElement('div');
    diagram.className = 'mermaid-diagram';
    diagram.innerHTML = svg;

    block.__diasproMermaidSvg = svg;
    head.append(title, openButton);
    block.append(head, diagram);
    return block;
  }

  function buildMermaidError(source, error) {
    const block = document.createElement('section');
    block.className = 'mermaid-block mermaid-block-error';

    const errorBox = document.createElement('div');
    errorBox.className = 'mermaid-error';

    const title = document.createElement('strong');
    title.textContent = 'Diagramma Mermaid non valido';

    const message = document.createElement('div');
    message.textContent = String(error || 'Errore sconosciuto');

    const raw = document.createElement('pre');
    const code = document.createElement('code');
    code.textContent = source;
    raw.appendChild(code);

    errorBox.append(title, message, raw);
    block.appendChild(errorBox);
    return block;
  }

  async function renderMermaidBlocks(version) {
    const mermaidCodes = Array.from(preview.querySelectorAll('pre > code.language-mermaid'));
    if (mermaidCodes.length === 0) return;

    if (!ensureMermaidInitialized()) {
      mermaidCodes.forEach((code) => {
        const source = code.textContent || '';
        code.parentElement.replaceWith(
          buildMermaidError(source, 'Renderer Mermaid non disponibile.'),
        );
      });
      return;
    }

    for (const code of mermaidCodes) {
      if (!isCurrent(version)) return;

      const source = code.textContent || '';
      const pre = code.parentElement;
      const cached = readCachedMermaid(source);

      if (cached) {
        pre.replaceWith(buildMermaidBlock(cached, source));
        continue;
      }

      try {
        const id = 'diaspro-mermaid-' + (++mermaidRenderSequence);
        const result = await window.mermaid.render(id, source);
        if (!isCurrent(version)) return;
        cacheMermaid(source, result.svg);
        pre.replaceWith(buildMermaidBlock(result.svg, source));
      } catch (error) {
        if (!isCurrent(version)) return;
        pre.replaceWith(buildMermaidError(source, error));
      }
    }
  }

  return { renderMermaidBlocks };
}
