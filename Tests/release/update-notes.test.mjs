import test from 'node:test';
import assert from 'node:assert/strict';
import { releaseNotesDescription } from '../../scripts/update-notes.mjs';

test('the signed feed embeds the reviewed Markdown and preserves CDATA-like user text', () => {
  const notes = '# Yuzu Converter 1.2.3\n\n## What changed\n\n- Fixed PDF crops & rotation.\n- Literal ]]> example.\n';
  const xml = releaseNotesDescription(notes, '1.2.3');
  assert.ok(xml.startsWith('<description sparkle:format="markdown"><![CDATA['));
  const decoded = [...xml.matchAll(/<!\[CDATA\[([\s\S]*?)\]\]>/g)].map(match => match[1]).join('');
  assert.equal(decoded, notes);
});

test('publication refuses missing, oversized, or wrong-version release notes', () => {
  for (const notes of ['', '# Yuzu Converter 1.2.2\n\n## What changed\n', '# Yuzu Converter 1.2.3\n',
    '# Yuzu Converter 1.2.3\n\n## What changed\n' + 'x'.repeat(256 * 1024)]) {
    assert.throws(() => releaseNotesDescription(notes, '1.2.3'), /release notes/);
  }
});
