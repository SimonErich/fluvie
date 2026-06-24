// Verifies the validation-error path: inject invalid code into the editor, hit
// Render, and confirm the server's diagnostics surface as inline markers, a
// problem count, and a blocked render. Needs the app built with FLUVIE_API_URL
// and the fluvie_server reachable. Coordinates tuned for 1600x1000.
import puppeteer from 'puppeteer-core';

const URL = process.env.URL || 'http://localhost:8090';
const CHROME = process.env.CHROME || '/usr/bin/google-chrome';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const shot = (page, name) => page.screenshot({ path: name });

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--no-sandbox', '--disable-gpu', '--hide-scrollbars'],
  defaultViewport: { width: 1600, height: 1000 },
});
const page = await browser.newPage();
await page.goto(URL, { waitUntil: 'networkidle2', timeout: 60000 }).catch(() => {});
await sleep(7000);

// The Code tab is the default in lesson mode. Focus the editor, select all, and
// replace the valid snippet with clearly invalid Dart.
await page.mouse.click(1200, 360, { steps: 4 });
await sleep(400);
await page.keyboard.down('Control');
await page.keyboard.press('KeyA');
await page.keyboard.up('Control');
await sleep(200);
await page.keyboard.type('@@@ not valid dart @@@', { delay: 25 });
await sleep(500);
await shot(page, 'v1-bad-code.png');

// Render triggers a validate; the diagnostics should block the render.
await page.mouse.click(1250, 948, { steps: 4 });
await sleep(7000);
await shot(page, 'v2-errors.png');
await page.screenshot({ path: 'v3-errorzoom.png', clip: { x: 940, y: 858, width: 650, height: 150 } });

await browser.close();
console.log('validation screenshots written');
