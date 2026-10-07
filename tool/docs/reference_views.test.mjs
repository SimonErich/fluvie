import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { capabilityViews, protocolViews } from './reference_views.mjs';

const reference = {
  schemaVersion: 1,
  tools: [{ name: 'generate_video', description: 'Create a video.', inputSchema: {
    type: 'object', properties: { prompt: { type: 'string' } }, required: ['prompt'],
  } }],
  examples: {
    http: { method: 'POST', path: '/v1/renders', body: { prompt: "The cat's life" } },
    mcp: { jsonrpc: '2.0', id: 1, method: 'tools/call', params: {
      name: 'generate_video', arguments: { prompt: "The cat's life" },
    } },
  },
};

test('protocol views preserve the actual wire body and quote shell data safely', () => {
  const views = protocolViews(reference);
  assert.match(views.http, /\$FLUVIE_API_URL\/v1\/renders/);
  assert.match(views.http, /cat'\\''s life/);
  assert.deepEqual(JSON.parse(views.mcp), reference.examples.mcp);
  assert.match(views.tools, /`generate_video`/);
  assert.match(views.tools, /`prompt`/);
  const argv = execFileSync('/bin/sh', ['-c',
    'curl() { printf "%s\\0" "$@"; };\n' + views.http], {
    env: { FLUVIE_API_URL: 'http://localhost:8080', FLUVIE_API_TOKEN: 'test-token' },
    encoding: 'utf8',
  }).split('\0').slice(0, -1);
  assert.deepEqual(argv, [
    '-X', 'POST', 'http://localhost:8080/v1/renders',
    '-H', 'Authorization: Bearer test-token', '-H', 'Content-Type: application/json',
    '--data', JSON.stringify(reference.examples.http.body, null, 2),
  ]);
});

test('unknown versions and invented tool arguments fail publication', () => {
  assert.throws(() => protocolViews({ ...reference, schemaVersion: 2 }), /schemaVersion/);
  const bad = structuredClone(reference);
  bad.examples.mcp.params.arguments.template = 'imaginary';
  assert.throws(() => protocolViews(bad), /template/);
});

test('capability views retain backend differences and evidence', () => {
  const views = capabilityViews({ schemaVersion: 1, backends: [
    { backend: 'mobile', exportModes: ['mp4'], videoCodecs: ['h264'], pixelFormats: ['yuv420p'],
      audio: true, snapshots: false, exactClipTiming: false, targetBitRate: true,
      crf: false, presets: false, evidence: ['packages/mobile/test/render_test.dart'],
      notes: ['Requires supported device codecs.'] },
  ] });
  assert.match(views.table, /\| CRF control \| no \|/);
  assert.match(views.table, /\| Audio \| yes \|/);
  assert.match(views.notes, /Requires supported device codecs/);
  assert.match(views.notes, /packages\/mobile\/test\/render_test.dart/);
  assert.throws(() => capabilityViews({ schemaVersion: 1, backends: [] }), /backends/);
});
