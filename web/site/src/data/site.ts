import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import contentJson from './content.json';

/// The site's data-driven content: the package list and the lesson gallery.
///
/// The curated copy (marketing roles, one-liners, lesson blurbs) lives in
/// `content.json`; the authoritative *set* of packages and lessons is read from
/// the monorepo at build time, so adding or removing one is caught here. A
/// mismatch throws and fails the build, the deterministic replacement for the old
/// hand-reconcile.

// The build runs from web/site, so the monorepo root is two levels up.
const repoRoot = join(process.cwd(), '..', '..');

export interface SitePackage {
  key: string;
  role: string;
  line: string;
  icon: string;
  primary?: boolean;
  badge?: string;
}

export interface SiteLesson {
  key: string;
  title: string;
  teaches: string;
  category: string;
  clip: boolean;
}

interface Content {
  packages: SitePackage[];
  lessons: SiteLesson[];
}

const content = contentJson as unknown as Content;

/// Published packages on disk: every `packages/<name>` whose pubspec is not
/// `publish_to: none`.
function publishedPackages(): Set<string> {
  const dir = join(repoRoot, 'packages');
  const names = new Set<string>();
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const pubspec = join(dir, entry.name, 'pubspec.yaml');
    if (!existsSync(pubspec)) continue;
    if (/^\s*publish_to:\s*["']?none/m.test(readFileSync(pubspec, 'utf8'))) continue;
    names.add(entry.name);
  }
  return names;
}

/// Lesson numbers on disk: `example/lib/lessons/NN_*.dart`.
function lessonKeys(): Set<string> {
  const dir = join(repoRoot, 'example', 'lib', 'lessons');
  const keys = new Set<string>();
  for (const file of readdirSync(dir)) {
    const match = /^(\d\d)_.*\.dart$/.exec(file);
    if (match) keys.add(match[1]);
  }
  return keys;
}

function assertInSync(label: string, onDisk: Set<string>, declared: Set<string>): void {
  const missing = [...onDisk].filter((k) => !declared.has(k));
  const extra = [...declared].filter((k) => !onDisk.has(k));
  if (missing.length || extra.length) {
    const parts = [
      missing.length ? `missing from content.json: ${missing.join(', ')}` : '',
      extra.length ? `not on disk: ${extra.join(', ')}` : '',
    ].filter(Boolean);
    throw new Error(`Landing ${label} out of sync (${parts.join('; ')}).`);
  }
}

assertInSync('packages', publishedPackages(), new Set(content.packages.map((p) => p.key)));
assertInSync('lessons', lessonKeys(), new Set(content.lessons.map((l) => l.key)));

const COUNT_WORDS = [
  'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
  'Nine', 'Ten', 'Eleven', 'Twelve',
];

export const packages: SitePackage[] = content.packages;
export const lessons: SiteLesson[] = content.lessons;
export const packageCountWord: string =
  packages.length < COUNT_WORDS.length ? COUNT_WORDS[packages.length] : String(packages.length);
