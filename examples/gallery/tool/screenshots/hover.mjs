// Hover probe: tight before/after crops to confirm hover state changes actually
// fire in headless Chrome and are visible. Run with the app served on :8090.
import puppeteer from 'puppeteer-core';

const URL = process.env.URL || 'http://localhost:8090';
const CHROME = process.env.CHROME || '/usr/bin/google-chrome';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--no-sandbox', '--disable-gpu', '--hide-scrollbars'],
  defaultViewport: { width: 1600, height: 1000 },
});
const page = await browser.newPage();
await page.goto(URL, { waitUntil: 'networkidle2', timeout: 60000 }).catch(() => {});
await sleep(7000);

// Render button (bottom of the right pane, lesson mode).
const renderClip = { x: 930, y: 905, width: 660, height: 75 };
await page.mouse.move(700, 500, { steps: 6 });
await sleep(500);
await page.screenshot({ path: 'h-render-off.png', clip: renderClip });
await page.mouse.move(1250, 948, { steps: 12 });
await sleep(900);
await page.screenshot({ path: 'h-render-on.png', clip: renderClip });

// A lesson nav tile.
const navClip = { x: 0, y: 196, width: 260, height: 84 };
await page.mouse.move(700, 500, { steps: 6 });
await sleep(400);
await page.screenshot({ path: 'h-nav-off.png', clip: navClip });
await page.mouse.move(130, 230, { steps: 12 });
await sleep(700);
await page.screenshot({ path: 'h-nav-on.png', clip: navClip });

await browser.close();
console.log('hover crops written');
