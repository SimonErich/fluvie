// Focused AI-edit verification: generate, open the edit overlay, type a change,
// Apply, and confirm the re-render. Dialog coords tuned from f4-edit-overlay.
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

// Generate a green video.
await page.mouse.click(130, 72, { steps: 4 });
await sleep(1200);
await page.mouse.click(1267, 560, { steps: 4 });
await sleep(300);
await page.keyboard.type('a calm green forest intro', { delay: 25 });
await page.mouse.click(1267, 690, { steps: 4 });
await sleep(28000);
await shot(page, 'e1-generated.png');

// Open the edit overlay and apply a colour change.
await page.mouse.click(1545, 948, { steps: 4 });
await sleep(1100);
await page.mouse.click(800, 505, { steps: 4 }); // focus the field
await sleep(300);
await page.keyboard.type('make the background purple', { delay: 25 });
await sleep(300);
await shot(page, 'e2-typed.png');
// Focus-traverse to the Apply action and activate it (robust vs. canvas pixels).
await page.keyboard.press('Tab');
await sleep(150);
await page.keyboard.press('Tab');
await sleep(150);
await page.keyboard.press('Enter');
await sleep(1500);
await shot(page, 'e3-applied.png');
await sleep(28000);
await shot(page, 'e4-rerendered.png');

await browser.close();
console.log('edit screenshots written');
