// Adapt the repo's Markdown docs into the Starlight content collection.
//
// The source of truth stays in /documentation (plain GitHub-flavored Markdown
// with compiled, tested code snippets and a leading H1). Starlight needs a
// frontmatter `title`, so this copies each page into src/content/docs, derives
// the title from the first H1, and removes that H1 (Starlight renders the title
// itself). The generated content is gitignored; the build runs this first.
import { mkdir, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..', '..');
const srcDir = join(repoRoot, 'documentation');
const outDir = join(here, '..', 'src', 'content', 'docs');

// The repo-facing status map is not a docs page.
const skip = new Set(['README.md']);

async function* walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else if (entry.name.endsWith('.md')) yield full;
  }
}

function yamlEscape(value) {
  return value.replace(/"/g, '\\"');
}

function adapt(markdown, fallbackTitle) {
  const lines = markdown.split('\n');
  let title = fallbackTitle;
  const headingIndex = lines.findIndex((l) => /^#\s+/.test(l));
  if (headingIndex !== -1) {
    title = lines[headingIndex].replace(/^#\s+/, '').trim();
    lines.splice(headingIndex, 1);
    // Drop a single blank line left behind by the removed heading.
    if (lines[headingIndex] === '') lines.splice(headingIndex, 1);
  }
  const body = lines.join('\n').replace(/^\n+/, '');
  return `---\ntitle: "${yamlEscape(title)}"\n---\n\n${body}`;
}

await rm(outDir, { recursive: true, force: true });
let count = 0;
for await (const file of walk(srcDir)) {
  const rel = relative(srcDir, file);
  if (skip.has(rel)) continue;
  const raw = await readFile(file, 'utf8');
  const fallback = rel.replace(/\.md$/, '').split('/').pop().replace(/[-_]/g, ' ');
  const out = join(outDir, rel);
  await mkdir(dirname(out), { recursive: true });
  await writeFile(out, adapt(raw, fallback));
  count += 1;
}
console.log(`imported ${count} docs pages into src/content/docs`);
