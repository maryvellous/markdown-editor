// HTML textareas expose line breaks as LF, independent of the file format.
export function normalizeLineEndings(content) {
  return content.replace(/\r\n?/g, '\n');
}

// Retain the exact original line endings when unchanged, even in mixed files.
// After editing, use the first existing line-ending style; new files use LF.
export function serializeDocument(snapshot, original) {
  if (snapshot === normalizeLineEndings(original)) return original;
  const ending = original.match(/\r\n|\r|\n/)?.[0] ?? '\n';
  return ending === '\n' ? snapshot : snapshot.replace(/\n/g, ending);
}
