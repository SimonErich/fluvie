# Documentation site

The source pages live in `documentation/`. The importer prepares Starlight
content; do not edit its generated pages. Use Node 22.12 or newer and run:

```sh
npm ci
npm run build
npm run check
```

The build refreshes the shared documentation corpus before importing the pages.
The check runs importer tests, verifies the corpus and checks local links in the
built site. Canonical Dart examples must also pass the workspace snippet checks.

## Dependencies

Upgrade Astro and Starlight together. Keep `compressHTML: true` to preserve
spaces between inline elements across compiler upgrades. After an update, check
the search index, code blocks, navigation and links as well as the build result.

The targeted `postcss-nested` override selects the patched selector parser while
Expressive Code still depends on the older parser range. It addresses
[GHSA-rj75-hqrm-r3gf](https://github.com/postcss/postcss-selector-parser/security/advisories/GHSA-rj75-hqrm-r3gf).
The advisory concerns untrusted selectors; this site processes repository-owned
styles at build time. Remove the override once the upstream dependency requires
`postcss-selector-parser` 7.1.6 or newer, then rebuild and run the audit again.
