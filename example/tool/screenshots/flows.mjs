// Interaction-flow harness: drives the core usability paths and screenshots
// each step. Coordinates are tuned for a 1600x1000 viewport; full-frame shots
// let us recalibrate. Run with the app served on :8090.
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

// 1) Motions tab (right pane, second tab).
await page.mouse.click(1430, 112, { steps: 4 });
await sleep(1200);
await shot(page, 'f1-motions.png');

// 2) Select a different lesson (Timing and triggers, ~4th nav row).
await page.mouse.click(130, 275, { steps: 4 });
await sleep(2500);
await shot(page, 'f2-lesson-switch.png');

// 3) AI Assistant -> generate a green video.
await page.mouse.click(130, 72, { steps: 4 });
await sleep(1200);
await page.mouse.click(1267, 560, { steps: 4 });
await sleep(300);
await page.keyboard.type('a calm green forest intro', { delay: 25 });
await page.mouse.click(1267, 690, { steps: 4 });
await sleep(28000);
await shot(page, 'f3-ai-ready.png');

// 4) Edit with AI: open the overlay (the AI button is right of Render).
await page.mouse.click(1545, 948, { steps: 4 });
await sleep(1200);
await shot(page, 'f4-edit-overlay.png');

// 5) Type a change and apply.
await page.mouse.click(800, 470, { steps: 4 });
await sleep(300);
await page.keyboard.type('make the background purple', { delay: 25 });
await sleep(300);
await shot(page, 'f5-edit-typed.png');
await page.mouse.click(853, 556, { steps: 4 }); // Apply
await sleep(28000);
await shot(page, 'f6-edit-rerendered.png');

await browser.close();
console.log('flow screenshots written');
