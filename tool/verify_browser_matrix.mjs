// Real engines, production bridges and compiled Flutter application. Bootstrap
// dependencies with verify_browser_matrix.sh; no browser capability is mocked.
import { createServer } from 'node:http';
import { readFile, stat, mkdir, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectBrowsers } from './browser_matrix_selection.mjs';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = resolve(process.env.FLUVIE_BROWSER_OUT || resolve(repo, 'build/release-hardening/browsers'));
const require = createRequire(resolve(repo, 'build/release-hardening/browser-tools/package.json'));
const { chromium, firefox, webkit } = require('playwright-core');
const assertions = await readFile(resolve(repo, 'apps/slides/tool/browser_pixel_oracle.js'), 'utf8') + '\n' +
  await readFile(resolve(repo, 'apps/slides/tool/browser_encoder_assertions.js'), 'utf8');
const source = resolve(repo, 'apps/slides/web');
const release = resolve(repo, 'apps/slides/build/web');
await mkdir(out, { recursive: true });
const report = { platform: process.platform, playwright: require('playwright-core/package.json').version, results: [] };
// Replace stale evidence before launching anything, including a failed filter.
let selected;
try {
  selected = selectBrowsers(process.env.FLUVIE_BROWSERS);
  report.requestedBrowsers = selected;
} catch (error) {
  report.error = String(error);
  await writeFile(resolve(out, 'report.json'), JSON.stringify(report, null, 2));
  throw error;
}
await writeFile(resolve(out, 'report.json'), JSON.stringify(report, null, 2));

async function serve(root, bridges = false) {
  const server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      let file = resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
      if (file !== root && !file.startsWith(root + sep)) {
        response.writeHead(403).end(); return;
      }
      if (bridges && pathname === '/_fixture.mp4') {
        file = resolve(repo, 'examples/gallery/assets/fixtures/clip_1s.mp4');
      }
      const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.mp4': 'video/mp4', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf' };
      const info = await stat(file);
      if (!info.isFile()) { response.writeHead(404).end(); return; }
      let bytes = await readFile(file);
      if (bridges && pathname === '/') {
        bytes = bytes.toString().replace('$FLUTTER_BASE_HREF', '/').replace(/<script[^>]*src="flutter_bootstrap.js"[^>]*><\/script>/g, '');
      }
      response.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream' }).end(bytes);
    } catch (error) {
      response.writeHead(error.code === 'ENOENT' ? 404 : 500).end(String(error));
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  return { server, url: `http://127.0.0.1:${server.address().port}` };
}

const bridge = await serve(source, true);
const app = await serve(release);
let failed = false;
try {
  for (const [name, engine, options] of [
    ['chrome', chromium, {
      ...(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : { channel: 'chrome' }),
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    }],
    ['firefox', firefox, {}],
    ['webkit-linux', webkit, {}],
  ]) {
    if (!selected.includes(name)) continue;
    let browser;
    let page;
    const result = { name };
    const errors = [];
    try {
      console.log(`Starting ${name}`);
      browser = await engine.launch({ headless: true, ...options });
      result.version = browser.version();
      page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
      page.on('pageerror', error => errors.push(String(error)));
      await page.goto(bridge.url);
      result.capabilities = await page.evaluate(() => ({
        videoDecoder: typeof VideoDecoder !== 'undefined',
        offscreenCanvas: typeof OffscreenCanvas !== 'undefined',
        webAssembly: typeof WebAssembly !== 'undefined',
      }));
      result.media = await page.evaluate(async expression => {
        let timer;
        try {
          return await Promise.race([
            (0, eval)(expression),
            new Promise((_, reject) => { timer = setTimeout(() => reject(Error('Media acceptance exceeded 150 seconds')), 150000); }),
          ]);
        } finally { clearTimeout(timer); }
      }, assertions);
      console.log(`${name}: media accepted, opening application`);
      await page.goto(app.url);
      await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 60000 });
      const semantics = page.locator('flt-semantics-placeholder');
      await semantics.waitFor({ state: 'attached', timeout: 60000 });
      await semantics.evaluate(element => element.click());
      await page.getByRole('button', { name: /^New deck/ }).first().waitFor({ timeout: 60000 });
      await page.screenshot({ path: resolve(out, `${name}-main.png`) });
      result.mainAppBoot = true;
      await page.getByRole('button', { name: /^New deck/ }).first().click();
      await page.getByText('An empty slide', { exact: false }).waitFor({ timeout: 30000 });
      await page.screenshot({ path: resolve(out, `${name}-editor.png`) });
      result.editorOpened = true;
      // A real speaker popup starts in a fresh browsing context. Changing the
      // hash of the running main app can invoke its route normalisation first.
      await page.goto('about:blank');
      await page.goto(`${app.url}/#/speaker`);
      await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 60000 });
      await semantics.waitFor({ state: 'attached', timeout: 60000 });
      await semantics.evaluate(element => element.click());
      await page.getByText('Nothing is being presented yet.', { exact: false }).waitFor({ timeout: 60000 });
      await page.screenshot({ path: resolve(out, `${name}-speaker.png`) });
      result.speakerAppBoot = true;
      result.pageErrors = errors;
      if (errors.length) throw Error(errors.join('\n'));
      result.passed = true;
    } catch (error) {
      if (page) {
        const pixels = await page.evaluate(() => Array.from(globalThis.__fluviePixelDiagnostic || [])).catch(() => []);
        if (pixels.length) await writeFile(resolve(out, `${name}-decoded.rgba`), Buffer.from(pixels));
        await page.screenshot({ path: resolve(out, `${name}-failure.png`) }).catch(() => {});
        const html = await page.content().catch(() => 'The page closed before DOM capture.');
        await writeFile(resolve(out, `${name}-failure.html`), html).catch(() => {});
      }
      result.passed = false;
      result.error = String(error.stack || error);
      result.pageErrors = errors;
      failed = true;
    } finally {
      await browser?.close();
      report.results.push(result);
      await writeFile(resolve(out, 'report.json'), JSON.stringify(report, null, 2));
      console.log(JSON.stringify(result));
    }
  }
} finally {
  await Promise.all([bridge, app].map(({ server }) => new Promise(resolve => server.close(resolve))));
}
if (failed) process.exitCode = 1;
