import assert from 'node:assert/strict';
import { test } from 'node:test';
import { browserNames, selectBrowsers } from '../browser_matrix_selection.mjs';

test('unset means every engine; valid filters allow whitespace and deduplicate', () => {
  assert.deepEqual(selectBrowsers(undefined), browserNames);
  assert.deepEqual(selectBrowsers(' firefox, chrome,firefox '), ['firefox', 'chrome']);
});

test('empty filters, unknown names and partially misspelled lists fail', () => {
  for (const value of ['', ' ', ',', 'webkit', 'chrome,', 'chrome,chromium']) {
    assert.throws(() => selectBrowsers(value), /FLUVIE_BROWSERS/);
  }
});
