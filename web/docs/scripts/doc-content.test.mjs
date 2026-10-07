import assert from 'node:assert/strict';
import test from 'node:test';
import { adaptMarkdown, publishedLink } from './doc-content.mjs';

test('source links resolve to routes, including anchors and references', () => {
  assert.equal(publishedLink('../guides/audio-and-captions.md#music', 'getting-started/start-a-project.md'), '/guides/audio-and-captions/#music');
  assert.equal(publishedLink('https://example.com/page.md', 'guides/a.md'), 'https://example.com/page.md');
  assert.equal(publishedLink('../../examples/gallery/README.md', 'guides/a.md'), 'https://github.com/SimonErich/fluvie/blob/main/examples/gallery/README.md');
  assert.equal(publishedLink('../index.md#start', 'guides/a.md'), '/#start');
  const page = adaptMarkdown('# Title\n\n[guide](b.md)\n[ref]: b.md#x\n```dart\nconst source = "[keep](b.md)";\n```\n', 'guides/a.md');
  assert.ok(page.includes('editUrl: "https://github.com/SimonErich/fluvie/edit/main/documentation/guides/a.md"'));
  assert.ok(page.includes('[guide](/guides/b/)'));
  assert.ok(page.includes('[ref]: /guides/b/#x'));
  assert.ok(page.includes('const source = "[keep](b.md)";'));
});

test('wrapped Markdown labels adapt without changing fenced code', () => {
  const page = adaptMarkdown('# Title\n\n[source-checkout\ninstaller](installation.md#source)\n```md\n[keep\nlabel](installation.md)\n```\n', 'getting-started/start-a-project.md');
  assert.ok(page.includes('[source-checkout\ninstaller](/getting-started/installation/#source)'));
  assert.ok(page.includes('[keep\nlabel](installation.md)'));
});

test('links to non-Markdown repository examples publish as source links', () => {
  const source = '../../packages/fluvie_editor/test/widgets/track_timeline_configuration_test.dart';
  const page = adaptMarkdown(`# Timeline\n\n[configuration example](${source}#L20)\n`, 'reference/track-timeline.md');
  assert.ok(page.includes('[configuration example](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_editor/test/widgets/track_timeline_configuration_test.dart#L20)'));
  assert.equal(publishedLink('diagram.svg', 'guides/a.md'), 'diagram.svg');
});
