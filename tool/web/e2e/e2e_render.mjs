// Drives a built Fluvie web example in headless Chrome: loads the served app
// (built with --dart-define=FLUVIE_E2E=true so it auto-renders), then reads the
// app's `FLUVIE_E2E_RESULT` marker from the console. Exits non-zero on failure.
//
// Env: URL (served app), CHROME (browser path), E2E_TIMEOUT_MS.
import puppeteer from 'puppeteer-core';

const URL = process.env.URL;
const CHROME = process.env.CHROME || process.env.CHROME_PATH || '/usr/bin/google-chrome';
const TIMEOUT = Number(process.env.E2E_TIMEOUT_MS || 240000);

if (!URL) {
  console.error('URL is required');
  process.exit(2);
}

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--no-sandbox', '--disable-gpu', '--hide-scrollbars'],
  defaultViewport: { width: 1280, height: 900 },
});
const page = await browser.newPage();

let marker = null;
const crashes = [];
page.on('pageerror', (e) => crashes.push(e.message || String(e)));
page.on('console', (m) => {
  const text = m.text();
  if (text.includes('FLUVIE_E2E_RESULT') || text.includes('FLUVIE_E2E_ERROR')) marker = text;
});

try {
  await page.goto(URL, { waitUntil: 'load', timeout: 60000 });
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 45000 });
  const start = Date.now();
  while (marker === null && Date.now() - start < TIMEOUT) {
    await new Promise((r) => setTimeout(r, 500));
  }
} finally {
  await browser.close();
}

if (marker === null) {
  console.error(`E2E FAILED: no FLUVIE_E2E_RESULT marker within ${TIMEOUT}ms`);
  if (crashes.length) console.error('crashes:\n  ' + crashes.slice(0, 5).join('\n  '));
  process.exit(1);
}

console.log('marker: ' + marker);
if (!marker.includes('FLUVIE_E2E_RESULT ok')) {
  console.error('E2E FAILED: ' + marker);
  process.exit(1);
}
const bytesMatch = /bytes=(\d+) ftyp=(\w+)/.exec(marker);
if (bytesMatch && (Number(bytesMatch[1]) <= 0 || bytesMatch[2] !== 'ftyp')) {
  console.error('E2E FAILED: rendered bytes are not a valid MP4');
  process.exit(1);
}
console.log('E2E OK');
