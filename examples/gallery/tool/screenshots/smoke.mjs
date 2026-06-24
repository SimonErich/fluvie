// Deterministic web smoke test for the Fluvie demo: loads the served app in
// headless Chrome and asserts it boots, lays out, and logs no uncaught error.
// Needs no API/server (the default lesson view renders offline; a missing
// /media video is a benign 404, not a failure). Exits non-zero on any failure.
//
// Env: URL (served app), CHROME (browser path), SHOT (screenshot output).
import puppeteer from 'puppeteer-core';

const URL = process.env.URL || 'http://localhost:8090';
const CHROME = process.env.CHROME || process.env.CHROME_PATH || '/usr/bin/google-chrome';
const SHOT = process.env.SHOT || 'smoke.png';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const failures = [];
const check = (ok, msg) => {
  if (!ok) failures.push(msg);
};

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--no-sandbox', '--disable-gpu', '--hide-scrollbars'],
  defaultViewport: { width: 1280, height: 800 },
});
const page = await browser.newPage();

// Uncaught JS exceptions fail the smoke test; console noise (e.g. a 404 for a
// not-yet-rendered /media video) is logged but tolerated.
const crashes = [];
const consoleErrors = [];
page.on('pageerror', (e) => crashes.push('pageerror: ' + (e.message || e)));
page.on('console', (m) => {
  if (m.type() === 'error') consoleErrors.push(m.text());
});

try {
  const resp = await page
    .goto(URL, { waitUntil: 'load', timeout: 60000 })
    .catch((e) => {
      failures.push('navigation failed: ' + e.message);
      return null;
    });
  check(resp != null && resp.ok(), `bad navigation status: ${resp && resp.status()}`);

  await page
    .waitForSelector('flutter-view, flt-glass-pane', { timeout: 45000 })
    .catch(() => failures.push('flutter-view never appeared (app did not boot)'));

  await sleep(6000); // let the first frame paint and fonts apply

  const info = await page.evaluate(() => {
    const host =
      document.querySelector('flutter-view') || document.querySelector('flt-glass-pane');
    if (!host) return null;
    const r = host.getBoundingClientRect();
    return { tag: host.tagName.toLowerCase(), w: Math.round(r.width), h: Math.round(r.height) };
  });
  check(info != null, 'no flutter host element in the DOM');
  check(info != null && info.w >= 800 && info.h >= 400, `flutter host too small: ${JSON.stringify(info)}`);

  await page.screenshot({ path: SHOT });

  check(crashes.length === 0, 'uncaught runtime errors:\n  ' + crashes.slice(0, 8).join('\n  '));

  console.log(
    `smoke: host=${info ? `${info.tag} ${info.w}x${info.h}` : 'none'}, ` +
      `crashes=${crashes.length}, console.errors=${consoleErrors.length}`,
  );
} finally {
  await browser.close();
}

if (failures.length) {
  console.error('SMOKE FAILED:\n- ' + failures.join('\n- '));
  process.exit(1);
}
console.log('SMOKE OK');
