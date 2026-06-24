// A dev-only browser harness: screenshots the served Fluvie demo through the
// system Chrome so the restyle can be verified against the landing page.
//
// Flutter web renders to a CanvasKit canvas (no DOM to select), so every
// interaction is a coordinate click/move tuned for a 1600x1000 viewport.
//
// Usage: node shoot.mjs  (server must be running, default http://localhost:8090)
import puppeteer from 'puppeteer-core';

const URL = process.env.URL || 'http://localhost:8090';
const OUT = process.env.OUT || '.';
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
await page.waitForSelector('flt-glass-pane, flutter-view, canvas', { timeout: 30000 }).catch(() => {});
await sleep(7000); // let Flutter boot, render, and the default video load
await page.screenshot({ path: `${OUT}/01-lesson.png` });

// Switch to AI Assistant (the first nav tile).
await page.mouse.click(130, 72);
await sleep(1500);
await page.screenshot({ path: `${OUT}/02-ai-idle.png` });

// Type a prompt and generate (the field is mid-panel; the button below it).
await page.mouse.click(1267, 560);
await sleep(400);
await page.keyboard.type('A bold red SALE intro', { delay: 25 });
await sleep(400);
await page.screenshot({ path: `${OUT}/03-ai-typed.png` });
await page.mouse.click(1267, 690);
await sleep(2500);
await page.screenshot({ path: `${OUT}/04-ai-generating.png` });
await sleep(26000); // stub generation + validate + capture + encode
await page.screenshot({ path: `${OUT}/05-ai-ready.png` });

// Hover the Render button (ready state, bottom of the editor pane).
await page.mouse.move(1267, 905);
await sleep(700);
await page.screenshot({ path: `${OUT}/06-render-hover.png` });

await browser.close();
console.log('screenshots written to', OUT);
