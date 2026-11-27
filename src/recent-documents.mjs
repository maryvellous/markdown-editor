export function createRecentDocuments({ recentList, recentEmpty, clearRecentBtn, openRecent, getStorage = () => window.localStorage }) {
  const RECENTS_KEY = 'diaspro-markdown.recents.v1';
  const MAX_RECENTS = 8;

  function getRecents() {
    try {
      const parsed = JSON.parse(getStorage().getItem(RECENTS_KEY) || '[]');
      if (!Array.isArray(parsed)) return [];
      return parsed
        .filter((item) => item && typeof item.path === 'string' && typeof item.name === 'string')
        .slice(0, MAX_RECENTS);
    } catch {
      return [];
    }
  }

  function storeRecents(items) {
    const clean = items.slice(0, MAX_RECENTS);
    try {
      getStorage().setItem(RECENTS_KEY, JSON.stringify(clean));
    } catch {
      // Se localStorage non è disponibile, l’app continua semplicemente senza cronologia.
    }
    renderRecents(clean);
  }

  function normalizeRecentPath(path) {
    return String(path || '').toLocaleLowerCase();
  }

  function addRecent(documentData) {
    if (!documentData || !documentData.path) return;
    const target = normalizeRecentPath(documentData.path);
    const next = getRecents().filter((item) => normalizeRecentPath(item.path) !== target);
    next.unshift({ path: documentData.path, name: documentData.name || 'documento.md' });
    storeRecents(next);
  }

  function removeRecent(path) {
    const target = normalizeRecentPath(path);
    storeRecents(getRecents().filter((item) => normalizeRecentPath(item.path) !== target));
  }

  function renderRecents(items = getRecents()) {
    recentList.replaceChildren();
    recentEmpty.hidden = items.length > 0;
    clearRecentBtn.disabled = items.length === 0;

    items.forEach((item) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'recent-item';
      button.title = item.path;

      const name = document.createElement('span');
      name.className = 'recent-name';
      name.textContent = item.name;

      const path = document.createElement('span');
      path.className = 'recent-path';
      path.textContent = item.path;

      button.append(name, path);
      button.addEventListener('click', () => openRecent(item.path));
      recentList.appendChild(button);
    });
  }

  return { addRecent, removeRecent, renderRecents, storeRecents };
}
