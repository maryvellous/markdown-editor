export function createMermaidViewer({ mermaidViewer, mermaidViewerCanvas, mermaidViewerContent, mermaidZoomOutBtn, mermaidZoomResetBtn, mermaidZoomInBtn, mermaidFitBtn, mermaidCloseBtn }) {
  const viewerState = {
    svg: '',
    scale: 1,
    x: 0,
    y: 0,
    naturalWidth: 0,
    naturalHeight: 0,
    dragging: false,
    pointerId: null,
    startPointerX: 0,
    startPointerY: 0,
    startX: 0,
    startY: 0,
  };

  function getSvgNaturalSize(svgElement) {
    const viewBox = svgElement?.viewBox?.baseVal;
    if (viewBox && viewBox.width > 0 && viewBox.height > 0) {
      return { width: viewBox.width, height: viewBox.height };
    }

    const width = Number.parseFloat(svgElement?.getAttribute('width')) || svgElement?.getBoundingClientRect().width || 900;
    const height = Number.parseFloat(svgElement?.getAttribute('height')) || svgElement?.getBoundingClientRect().height || 600;
    return { width, height };
  }

  function applyViewerTransform() {
    mermaidViewerContent.style.transform =
      'translate(' + viewerState.x + 'px, ' + viewerState.y + 'px) scale(' + viewerState.scale + ')';
    mermaidZoomResetBtn.textContent = Math.round(viewerState.scale * 100) + '%';
  }

  function centerViewerAtScale(scale) {
    const canvasRect = mermaidViewerCanvas.getBoundingClientRect();
    viewerState.scale = Math.max(0.15, Math.min(8, scale));
    viewerState.x = (canvasRect.width - viewerState.naturalWidth * viewerState.scale) / 2;
    viewerState.y = (canvasRect.height - viewerState.naturalHeight * viewerState.scale) / 2;
    applyViewerTransform();
  }

  function fitMermaidViewer() {
    if (!viewerState.naturalWidth || !viewerState.naturalHeight) return;
    const canvasRect = mermaidViewerCanvas.getBoundingClientRect();
    const padding = 56;
    const fitScale = Math.min(
      (canvasRect.width - padding) / viewerState.naturalWidth,
      (canvasRect.height - padding) / viewerState.naturalHeight,
    );
    centerViewerAtScale(Math.max(0.15, Math.min(4, fitScale)));
  }

  function setViewerScale(nextScale) {
    const canvasRect = mermaidViewerCanvas.getBoundingClientRect();
    const centerX = canvasRect.width / 2;
    const centerY = canvasRect.height / 2;
    const oldScale = viewerState.scale || 1;
    const scale = Math.max(0.15, Math.min(8, nextScale));
    const contentX = (centerX - viewerState.x) / oldScale;
    const contentY = (centerY - viewerState.y) / oldScale;

    viewerState.scale = scale;
    viewerState.x = centerX - contentX * scale;
    viewerState.y = centerY - contentY * scale;
    applyViewerTransform();
  }

  function openMermaidViewer(svg) {
    if (!svg) return;
    viewerState.svg = svg;
    mermaidViewerContent.innerHTML = svg;
    mermaidViewer.hidden = false;
    mermaidViewer.setAttribute('aria-hidden', 'false');

    window.requestAnimationFrame(() => {
      const svgElement = mermaidViewerContent.querySelector('svg');
      const size = getSvgNaturalSize(svgElement);
      viewerState.naturalWidth = size.width;
      viewerState.naturalHeight = size.height;
      if (svgElement) {
        svgElement.style.width = size.width + 'px';
        svgElement.style.height = size.height + 'px';
      }
      fitMermaidViewer();
      mermaidCloseBtn.focus();
    });
  }

  function closeMermaidViewer() {
    mermaidViewer.hidden = true;
    mermaidViewer.setAttribute('aria-hidden', 'true');
    mermaidViewerContent.replaceChildren();
    viewerState.dragging = false;
    viewerState.pointerId = null;
  }

  function setupMermaidViewer() {
    mermaidZoomOutBtn.addEventListener('click', () => setViewerScale(viewerState.scale / 1.25));
    mermaidZoomInBtn.addEventListener('click', () => setViewerScale(viewerState.scale * 1.25));
    mermaidZoomResetBtn.addEventListener('click', () => centerViewerAtScale(1));
    mermaidFitBtn.addEventListener('click', fitMermaidViewer);
    mermaidCloseBtn.addEventListener('click', closeMermaidViewer);

    mermaidViewer.addEventListener('click', (event) => {
      if (event.target === mermaidViewer) closeMermaidViewer();
    });

    mermaidViewerCanvas.addEventListener('wheel', (event) => {
      event.preventDefault();
      const direction = event.deltaY < 0 ? 1.12 : 1 / 1.12;
      setViewerScale(viewerState.scale * direction);
    }, { passive: false });

    mermaidViewerCanvas.addEventListener('pointerdown', (event) => {
      if (event.button !== 0) return;
      viewerState.dragging = true;
      viewerState.pointerId = event.pointerId;
      viewerState.startPointerX = event.clientX;
      viewerState.startPointerY = event.clientY;
      viewerState.startX = viewerState.x;
      viewerState.startY = viewerState.y;
      mermaidViewerCanvas.classList.add('is-dragging');
      mermaidViewerCanvas.setPointerCapture(event.pointerId);
    });

    mermaidViewerCanvas.addEventListener('pointermove', (event) => {
      if (!viewerState.dragging || event.pointerId !== viewerState.pointerId) return;
      viewerState.x = viewerState.startX + event.clientX - viewerState.startPointerX;
      viewerState.y = viewerState.startY + event.clientY - viewerState.startPointerY;
      applyViewerTransform();
    });

    const stopDragging = (event) => {
      if (!viewerState.dragging) return;
      if (event.pointerId !== undefined && event.pointerId !== viewerState.pointerId) return;
      viewerState.dragging = false;
      mermaidViewerCanvas.classList.remove('is-dragging');
      viewerState.pointerId = null;
    };

    mermaidViewerCanvas.addEventListener('pointerup', stopDragging);
    mermaidViewerCanvas.addEventListener('pointercancel', stopDragging);

    window.addEventListener('resize', () => {
      if (!mermaidViewer.hidden) fitMermaidViewer();
    });
  }

  return { openMermaidViewer, closeMermaidViewer, setupMermaidViewer };
}
