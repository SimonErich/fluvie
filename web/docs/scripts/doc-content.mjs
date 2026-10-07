import { posix } from 'node:path';

const sourceBase = 'https://github.com/SimonErich/fluvie/blob/main/';
const editBase = 'https://github.com/SimonErich/fluvie/edit/main/documentation/';

/** Turn a source Markdown link into its published route or repository source. */
export function publishedLink(href, sourcePath) {
  if (/^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(href)) return href;
  const match = href.match(/^([^?#]+)(.*)$/);
  if (!match) return href;
  const target = posix.normalize(posix.join(posix.dirname(sourcePath), match[1]));
  if (target.startsWith('../')) {
    return `${sourceBase}${posix.normalize(posix.join('documentation', target))}${match[2]}`;
  }
  if (!match[1].endsWith('.md')) return href;
  if (posix.basename(target) === 'README.md') return `${sourceBase}documentation/${target}${match[2]}`;
  if (target === 'index.md') return `/${match[2]}`;
  return `/${target.slice(0, -3)}/${match[2]}`;
}

function adaptLinks(markdown, sourcePath) {
  return markdown
    .replace(/(\[[^\]]*\]\()([^\s)]+)([^)]*\))/g,
      (_, before, href, after) => `${before}${publishedLink(href, sourcePath)}${after}`)
    .replace(/^(\s*\[[^\]]+\]:\s*)(\S+)/gm,
      (_, before, href) => `${before}${publishedLink(href, sourcePath)}`);
}

/** Preserve compiled snippets while adapting source links and page metadata. */
export function adaptMarkdown(markdown, sourcePath) {
  const lines = markdown.split('\n');
  const headingIndex = lines.findIndex((line) => /^#\s+/.test(line));
  const title = headingIndex < 0
    ? posix.basename(sourcePath, '.md').replace(/[-_]/g, ' ')
    : lines.splice(headingIndex, 1)[0].replace(/^#\s+/, '').trim();
  let fence;
  const output = [];
  let prose = [];
  const flushProse = () => {
    if (prose.length) output.push(adaptLinks(prose.join('\n'), sourcePath));
    prose = [];
  };
  for (const line of lines) {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    if (marker) {
      flushProse();
      if (!fence) fence = marker[1][0];
      else if (fence === marker[1][0]) fence = undefined;
      output.push(line);
    } else if (fence) {
      output.push(line);
    } else {
      prose.push(line);
    }
  }
  flushProse();
  const body = output.join('\n').replace(/^\n+/, '');
  return `---\ntitle: ${JSON.stringify(title)}\neditUrl: ${JSON.stringify(editBase + sourcePath)}\n---\n\n${body}`;
}
