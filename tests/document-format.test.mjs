import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeLineEndings, serializeDocument } from '../src/document-format.mjs';

test('CRLF files have a clean editor baseline immediately after opening', () => {
  assert.equal(normalizeLineEndings('# Titolo\r\n\r\nTesto\r\n'), '# Titolo\n\nTesto\n');
});

test('unchanged files retain their exact line endings', () => {
  for (const original of ['', 'a\nb\n', 'a\r\nb\r\n', 'a\r\nb\nc\r', 'a\rb']) {
    assert.equal(serializeDocument(normalizeLineEndings(original), original), original);
  }
});

test('edited CRLF documents keep Windows line endings on save and save-as', () => {
  assert.equal(serializeDocument('a\nmodifica\n', 'a\r\nb\r\n'), 'a\r\nmodifica\r\n');
});

test('edited LF files and new files keep LF', () => {
  assert.equal(serializeDocument('a\nb\n', ''), 'a\nb\n');
  assert.equal(serializeDocument('a\nb\n', 'a\n'), 'a\nb\n');
});

test('mixed and legacy endings follow the first existing separator on edit', () => {
  assert.equal(serializeDocument('a\nb\nc', 'a\r\nb\n'), 'a\r\nb\r\nc');
  assert.equal(serializeDocument('a\nb\nc', 'a\rb'), 'a\rb\rc');
});
