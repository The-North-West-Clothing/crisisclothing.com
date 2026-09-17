# Crisis Clothing Gallery Site — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Astro static site — a gallery of Crisis Clothing designs with a detail page per design — deployable to GitHub Pages at `crisisclothing.com`.

**Architecture:** Astro 6, static output, zero client JS. Designs are entries in one Content Layer collection (`glob()` loader over Markdown files; Zod schema validated at build). The gallery (`/`) and per-design detail pages (`/designs/[slug]`) are generated from the collection. A GitHub Action builds and deploys to Pages; `public/CNAME` pins the custom domain.

**Tech Stack:** Astro 6, TypeScript, `@astrojs/check`, Vitest (for the one pure helper), `@fontsource` self-hosted fonts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-16-crisisclothing-gallery-design.md`

## Global Constraints

- Astro `^6` (current major). Node `24` in CI (withastro/action default).
- Actions pinned to latest majors: `actions/checkout@v7`, `withastro/action@v6`, `actions/deploy-pages@v5`.
- `astro.config.mjs`: `site: 'https://crisisclothing.com'`, **no `base`** (apex domain).
- Content config lives at `src/content.config.ts` (Astro 5+ location), collection name `designs`, loader `glob({ base: './src/content/designs', pattern: '**/[^_]*.md' })` (the `[^_]` guard means an `images/` sibling and `_`-prefixed files are ignored — but images go in a subdir which the `.md` pattern already skips; the guard also lets us add `_drafts` later).
- Schema fields (verbatim from spec): `title` string; `releaseDate` `z.coerce.date()`; `image` via `image()` helper; `gallery` optional array of `image()`; `links` optional array of `{ label: non-empty string, url: url }`; `draft` boolean default false. Description is the Markdown body.
- Gallery: newest-first by `releaseDate`, drafts excluded. Detail page omits the purchase section entirely when a design has no links.
- Palette (LOUD): green `#37C22B`, yellow `#F5E10A`, navy `#132452`, charcoal `#141414`, paper `#F7F5EF`. Green fields/hero; yellow wordmark & accents; navy/charcoal text on paper; **cards & detail content sit on paper, never under the loud fields**. WCAG AA for all real text.
- Type: self-hosted `@fontsource-variable/archivo` (grotesque, headings + body) and `@fontsource/ibm-plex-mono` (mono kicker labels, fine print). Script wordmark is the logo image only — not a font.
- No secrets in the repo. No `as` type assertions. Descriptive variable names (no single-char identifiers).
- Never boot the dev server; verify via `npm run build` and `npm run check`.

---

### Task 1: Scaffold the Astro project

**Files:**
- Create: `package.json`, `astro.config.mjs`, `tsconfig.json`
- Create: `src/pages/index.astro` (temporary placeholder, replaced in Task 5)

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable Astro project; `npm run build`, `npm run check`, `npm test` scripts.

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "crisisclothing-com",
  "type": "module",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview",
    "check": "astro check",
    "test": "vitest run"
  },
  "dependencies": {
    "astro": "^6.0.0",
    "@fontsource-variable/archivo": "^5.0.0",
    "@fontsource/ibm-plex-mono": "^5.0.0"
  },
  "devDependencies": {
    "@astrojs/check": "^0.9.0",
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: Create `tsconfig.json`**

```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "**/*"],
  "exclude": ["dist"]
}
```

- [ ] **Step 3: Create `astro.config.mjs`**

```js
import { defineConfig } from 'astro/config';

// Apex custom domain: set `site`, do NOT set `base`.
export default defineConfig({
  site: 'https://crisisclothing.com',
});
```

- [ ] **Step 4: Create a temporary `src/pages/index.astro`**

```astro
---
// Placeholder — replaced by the real gallery in Task 5.
---
<html lang="en">
  <head><meta charset="utf-8" /><title>Crisis Clothing</title></head>
  <body><h1>Crisis Clothing</h1></body>
</html>
```

- [ ] **Step 5: Install and build**

Run: `npm install && npm run build`
Expected: install succeeds; build writes `dist/index.html` with no errors.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json tsconfig.json astro.config.mjs src/pages/index.astro
git commit -m "Scaffold Astro project"
```

---

### Task 2: Design tokens and BaseLayout

**Files:**
- Create: `src/styles/global.css`
- Create: `src/layouts/BaseLayout.astro`
- Create: `public/crisis-wordmark-white.png` (copied brand asset, for the header)

**Interfaces:**
- Consumes: nothing.
- Produces: `BaseLayout.astro` — an Astro component with props `{ title: string; description?: string }` and a default `<slot />`; wraps page content with the site header (green field, yellow/white script wordmark) and footer, imports fonts + tokens. Later tasks wrap their pages in `<BaseLayout title={...}>`.

- [ ] **Step 1: Copy the wordmark asset into `public/`**

Run:
```bash
mkdir -p public
cp "$HOME/Library/CloudStorage/Dropbox/Crisis Clothing/Brand/Crisis-Logo copy.png" public/crisis-wordmark-white.png
```
(The white script wordmark reverses out cleanly on the green header field.)

- [ ] **Step 2: Create `src/styles/global.css` with palette + type tokens**

```css
:root {
  --green: #37c22b;
  --green-deep: #2ba321;
  --yellow: #f5e10a;
  --navy: #132452;
  --charcoal: #141414;
  --paper: #f7f5ef;
  --paper-line: #e2ddcf;

  --font-display: 'Archivo Variable', system-ui, sans-serif;
  --font-body: 'Archivo Variable', system-ui, sans-serif;
  --font-mono: 'IBM Plex Mono', ui-monospace, monospace;

  --measure: 68ch;
  --gutter: 1rem;
  --maxw: 1200px;
}

* { box-sizing: border-box; }

html { -webkit-text-size-adjust: 100%; }

body {
  margin: 0;
  background: var(--paper);
  color: var(--charcoal);
  font-family: var(--font-body);
  font-size: 1.0625rem;
  line-height: 1.5;
  font-synthesis: none;
}

h1, h2, h3 {
  font-family: var(--font-display);
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 0.95;
  margin: 0 0 0.4em;
}

a { color: inherit; }

img { max-width: 100%; height: auto; display: block; }

/* Monospace kicker label */
.kicker {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--navy);
}

.wrap { max-width: var(--maxw); margin-inline: auto; padding-inline: var(--gutter); }

/* Loud green header band with the script wordmark reversed out */
.site-header {
  background: var(--green);
  border-bottom: 3px solid var(--charcoal);
}
.site-header .wrap {
  display: flex;
  align-items: center;
  padding-block: 0.9rem;
}
.site-header a.brand { display: inline-block; }
.site-header img.wordmark { height: 40px; width: auto; }

.site-footer {
  background: var(--charcoal);
  color: var(--paper);
  margin-top: 4rem;
}
.site-footer .wrap {
  padding-block: 2rem;
  font-family: var(--font-mono);
  font-size: 0.8rem;
  letter-spacing: 0.04em;
}

:focus-visible { outline: 3px solid var(--navy); outline-offset: 2px; }
```

- [ ] **Step 3: Create `src/layouts/BaseLayout.astro`**

```astro
---
import '@fontsource-variable/archivo';
import '@fontsource/ibm-plex-mono';
import '../styles/global.css';

interface Props {
  title: string;
  description?: string;
}
const { title, description } = Astro.props;
const year = new Date().getFullYear();
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    {description && <meta name="description" content={description} />}
    <link rel="icon" href="/favicon.ico" sizes="any" />
  </head>
  <body>
    <header class="site-header">
      <div class="wrap">
        <a class="brand" href="/" aria-label="Crisis Clothing — home">
          <img class="wordmark" src="/crisis-wordmark-white.png" alt="Crisis Clothing" width="152" height="40" />
        </a>
      </div>
    </header>
    <main class="wrap">
      <slot />
    </main>
    <footer class="site-footer">
      <div class="wrap">© {year} Crisis Clothing</div>
    </footer>
  </body>
</html>
```

- [ ] **Step 4: Wire the placeholder index to BaseLayout, build, and check**

Replace `src/pages/index.astro` with:
```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
---
<BaseLayout title="Crisis Clothing">
  <h1>Crisis Clothing</h1>
</BaseLayout>
```

Run: `npm run build && npm run check`
Expected: build succeeds; check reports 0 errors.

- [ ] **Step 5: Commit**

```bash
git add src/styles/global.css src/layouts/BaseLayout.astro src/pages/index.astro public/crisis-wordmark-white.png
git commit -m "Add design tokens and BaseLayout with brand header"
```

---

### Task 3: Designs content collection + seed entry

**Files:**
- Create: `src/content.config.ts`
- Create: `src/content/designs/storm-relief-hoodie.md` (seed entry)
- Create: `src/content/designs/images/storm-relief-hoodie.png` (placeholder image)

**Interfaces:**
- Consumes: nothing.
- Produces: a `designs` collection queryable via `getCollection('designs')`. Each entry has `entry.id` (slug from filename), `entry.data.{title, releaseDate: Date, image, gallery?, links?, draft}`, and renders its Markdown body via `render(entry)`.

- [ ] **Step 1: Create `src/content.config.ts`**

```ts
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const designs = defineCollection({
  loader: glob({ base: './src/content/designs', pattern: '**/[^_]*.md' }),
  schema: ({ image }) =>
    z.object({
      title: z.string(),
      releaseDate: z.coerce.date(),
      image: image(),
      gallery: z.array(image()).optional(),
      links: z
        .array(
          z.object({
            label: z.string().min(1),
            url: z.string().url(),
          }),
        )
        .optional(),
      draft: z.boolean().default(false),
    }),
});

export const collections = { designs };
```

- [ ] **Step 2: Generate the placeholder image**

Run:
```bash
mkdir -p src/content/designs/images
magick -size 1200x1500 xc:'#37c22b' \
  -gravity center -font Helvetica-Bold -pointsize 90 -fill '#f5e10a' \
  -annotate 0 'CRISIS\nSAMPLE' \
  src/content/designs/images/storm-relief-hoodie.png
```
(If `magick` is unavailable, create any 1200×1500 PNG at that path.)

- [ ] **Step 3: Create the seed entry `src/content/designs/storm-relief-hoodie.md`**

```markdown
---
title: Storm Relief Hoodie
releaseDate: 2024-11-02
image: ./images/storm-relief-hoodie.png
links:
  - label: Buy on Etsy
    url: https://example.com/etsy/storm-relief-hoodie
  - label: Redbubble
    url: https://example.com/redbubble/storm-relief-hoodie
---

A heavyweight hoodie from the Crisis relief series. Placeholder copy — replace
with the real description. Supports **Markdown** for formatting.
```

- [ ] **Step 4: Build to verify the schema validates the entry**

Run: `npm run build`
Expected: build succeeds. (Introduce a deliberate error — e.g. delete the `releaseDate` line — re-run `npm run build`, confirm it FAILS with a schema error, then restore it. This proves validation is active.)

- [ ] **Step 5: Commit**

```bash
git add src/content.config.ts src/content/designs
git commit -m "Add designs content collection and seed entry"
```

---

### Task 4: Designs helper (sort, filter, format) — TDD

**Files:**
- Create: `src/lib/designs.ts`
- Create: `src/lib/designs.test.ts`

**Interfaces:**
- Consumes: nothing (pure functions over a minimal structural type, decoupled from `astro:content` so it is unit-testable).
- Produces:
  - `type DesignLike = { id: string; data: { releaseDate: Date; draft: boolean } }`
  - `sortedPublishedDesigns<Entry extends DesignLike>(entries: Entry[]): Entry[]` — filters out `draft`, sorts by `releaseDate` descending (newest first).
  - `formatReleaseDate(date: Date): string` — e.g. `"November 2, 2024"`.

- [ ] **Step 1: Write the failing test `src/lib/designs.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { sortedPublishedDesigns, formatReleaseDate } from './designs';

const make = (id: string, iso: string, draft = false) => ({
  id,
  data: { releaseDate: new Date(iso), draft },
});

describe('sortedPublishedDesigns', () => {
  it('sorts by releaseDate descending (newest first)', () => {
    const input = [
      make('older', '2023-01-01'),
      make('newest', '2025-06-01'),
      make('middle', '2024-03-15'),
    ];
    expect(sortedPublishedDesigns(input).map((entry) => entry.id)).toEqual([
      'newest',
      'middle',
      'older',
    ]);
  });

  it('excludes drafts', () => {
    const input = [make('shown', '2024-01-01'), make('hidden', '2025-01-01', true)];
    expect(sortedPublishedDesigns(input).map((entry) => entry.id)).toEqual(['shown']);
  });

  it('does not mutate the input array', () => {
    const input = [make('a', '2023-01-01'), make('b', '2024-01-01')];
    const before = input.map((entry) => entry.id);
    sortedPublishedDesigns(input);
    expect(input.map((entry) => entry.id)).toEqual(before);
  });
});

describe('formatReleaseDate', () => {
  it('formats as a long US date', () => {
    expect(formatReleaseDate(new Date('2024-11-02T00:00:00Z'))).toBe('November 2, 2024');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx vitest run src/lib/designs.test.ts`
Expected: FAIL — cannot import from `./designs` (module does not exist).

- [ ] **Step 3: Implement `src/lib/designs.ts`**

```ts
export type DesignLike = {
  id: string;
  data: { releaseDate: Date; draft: boolean };
};

export function sortedPublishedDesigns<Entry extends DesignLike>(entries: Entry[]): Entry[] {
  return entries
    .filter((entry) => !entry.data.draft)
    .slice()
    .sort((left, right) => right.data.releaseDate.getTime() - left.data.releaseDate.getTime());
}

const releaseDateFormatter = new Intl.DateTimeFormat('en-US', {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC',
});

export function formatReleaseDate(date: Date): string {
  return releaseDateFormatter.format(date);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npx vitest run src/lib/designs.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add src/lib/designs.ts src/lib/designs.test.ts
git commit -m "Add designs sort/filter/format helper with tests"
```

---

### Task 5: Gallery page and DesignCard

**Files:**
- Create: `src/components/DesignCard.astro`
- Modify: `src/pages/index.astro` (replace placeholder)

**Interfaces:**
- Consumes: `sortedPublishedDesigns`, `formatReleaseDate` from `../lib/designs`; `getCollection` from `astro:content`; `Image` from `astro:assets`.
- Produces: the gallery at `/`. `DesignCard` props: `{ slug: string; title: string; releaseDate: Date; image: ImageMetadata }`.

- [ ] **Step 1: Create `src/components/DesignCard.astro`**

```astro
---
import { Image } from 'astro:assets';
import { formatReleaseDate } from '../lib/designs';

interface Props {
  slug: string;
  title: string;
  releaseDate: Date;
  image: ImageMetadata;
}
const { slug, title, releaseDate, image } = Astro.props;
---
<a class="card" href={`/designs/${slug}/`}>
  <div class="card-image">
    <Image src={image} alt={title} width={800} height={1000} />
  </div>
  <p class="kicker">{formatReleaseDate(releaseDate)}</p>
  <h3>{title}</h3>
</a>

<style>
  .card {
    display: block;
    text-decoration: none;
    background: var(--paper);
  }
  .card-image {
    border: 3px solid var(--charcoal);
    background: #fff;
    overflow: hidden;
    aspect-ratio: 4 / 5;
  }
  .card-image :global(img) { width: 100%; height: 100%; object-fit: cover; }
  .card .kicker { margin: 0.6rem 0 0.15rem; }
  .card h3 { font-size: 1.35rem; }
  .card:hover .card-image { outline: 4px solid var(--green); outline-offset: 0; }
</style>
```

- [ ] **Step 2: Replace `src/pages/index.astro` with the gallery**

```astro
---
import { getCollection } from 'astro:content';
import BaseLayout from '../layouts/BaseLayout.astro';
import DesignCard from '../components/DesignCard.astro';
import { sortedPublishedDesigns } from '../lib/designs';

const designs = sortedPublishedDesigns(await getCollection('designs'));
---
<BaseLayout
  title="Crisis Clothing — Designs"
  description="The gallery of designs created by Crisis Clothing."
>
  <section class="hero">
    <p class="kicker" style="color: var(--charcoal)">The archive</p>
    <h1>Designs</h1>
  </section>

  {designs.length === 0 ? (
    <p>No designs yet.</p>
  ) : (
    <ul class="grid">
      {designs.map((design) => (
        <li>
          <DesignCard
            slug={design.id}
            title={design.data.title}
            releaseDate={design.data.releaseDate}
            image={design.data.image}
          />
        </li>
      ))}
    </ul>
  )}
</BaseLayout>

<style>
  .hero {
    background: var(--green);
    border: 3px solid var(--charcoal);
    margin: 1.5rem 0 2.5rem;
    padding: 2.5rem 1.5rem 2rem;
  }
  .hero h1 { font-size: clamp(3rem, 12vw, 7rem); color: var(--charcoal); }
  .grid {
    list-style: none;
    margin: 0;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 2rem 1.5rem;
  }
</style>
```

- [ ] **Step 3: Build and check**

Run: `npm run build && npm run check`
Expected: build succeeds (a `dist/designs/storm-relief-hoodie/index.html` will not exist yet — that's Task 6; the gallery links to it but Astro does not fail the build on that). Check reports 0 errors.

- [ ] **Step 4: Commit**

```bash
git add src/components/DesignCard.astro src/pages/index.astro
git commit -m "Add gallery page and DesignCard"
```

---

### Task 6: Design detail page

**Files:**
- Create: `src/pages/designs/[slug].astro`

**Interfaces:**
- Consumes: `getCollection`, `render` from `astro:content`; `Image` from `astro:assets`; `formatReleaseDate` from `../../lib/designs`.
- Produces: static detail pages at `/designs/<slug>/` for every **non-draft** design (drafts are not built, matching the spec). Uses `getStaticPaths` keyed on `entry.id`, filtered through `sortedPublishedDesigns`.

- [ ] **Step 1: Create `src/pages/designs/[slug].astro`**

```astro
---
import { getCollection, render } from 'astro:content';
import { Image } from 'astro:assets';
import BaseLayout from '../../layouts/BaseLayout.astro';
import { formatReleaseDate, sortedPublishedDesigns } from '../../lib/designs';

export async function getStaticPaths() {
  const designs = sortedPublishedDesigns(await getCollection('designs'));
  return designs.map((design) => ({
    params: { slug: design.id },
    props: { design },
  }));
}

const { design } = Astro.props;
const { title, releaseDate, image, gallery, links } = design.data;
const { Content } = await render(design);
---
<BaseLayout title={`${title} — Crisis Clothing`}>
  <article class="detail">
    <p class="kicker">{formatReleaseDate(releaseDate)}</p>
    <h1>{title}</h1>

    <div class="hero-image">
      <Image src={image} alt={title} width={1200} height={1500} />
    </div>

    <div class="body">
      <Content />
    </div>

    {gallery && gallery.length > 0 && (
      <div class="gallery">
        {gallery.map((shot) => (
          <Image src={shot} alt={`${title} — additional view`} width={800} height={1000} />
        ))}
      </div>
    )}

    {links && links.length > 0 && (
      <section class="purchase">
        <p class="kicker">Purchase</p>
        <div class="buttons">
          {links.map((link) => (
            <a class="buy" href={link.url} rel="noopener noreferrer" target="_blank">
              {link.label}
            </a>
          ))}
        </div>
      </section>
    )}

    <p class="back"><a href="/">← All designs</a></p>
  </article>
</BaseLayout>

<style>
  .detail { max-width: 900px; margin-inline: auto; padding-block: 2rem; }
  .detail h1 { font-size: clamp(2.5rem, 9vw, 5rem); margin-bottom: 1.2rem; }
  .hero-image { border: 3px solid var(--charcoal); background: #fff; }
  .body { max-width: var(--measure); font-size: 1.15rem; margin: 2rem 0; }
  .gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 1rem; margin: 2rem 0; }
  .gallery :global(img) { border: 3px solid var(--charcoal); }
  .purchase { margin: 2.5rem 0; }
  .buttons { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-top: 0.6rem; }
  .buy {
    display: inline-block;
    background: var(--green);
    color: var(--charcoal);
    border: 3px solid var(--charcoal);
    padding: 0.7rem 1.3rem;
    font-family: var(--font-mono);
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    text-decoration: none;
  }
  .buy:hover { background: var(--yellow); }
  .back { margin-top: 3rem; font-family: var(--font-mono); }
</style>
```

- [ ] **Step 2: Build and check**

Run: `npm run build && npm run check`
Expected: build succeeds; `dist/designs/storm-relief-hoodie/index.html` now exists. Check reports 0 errors.

- [ ] **Step 3: Verify the generated detail page content**

Run: `grep -c "Buy on Etsy" dist/designs/storm-relief-hoodie/index.html`
Expected: `1` (purchase links rendered). Also confirm the gallery links resolve: `test -f dist/designs/storm-relief-hoodie/index.html && echo OK`.

- [ ] **Step 4: Commit**

```bash
git add src/pages/designs/[slug].astro
git commit -m "Add design detail page"
```

---

### Task 7: CNAME, favicon, and GitHub Pages deploy workflow

**Files:**
- Create: `public/CNAME`
- Create: `public/favicon.ico` (from a brand asset)
- Create: `.github/workflows/deploy.yml`

**Interfaces:**
- Consumes: the buildable site from prior tasks.
- Produces: an on-push deploy to GitHub Pages that preserves the custom domain.

- [ ] **Step 1: Create `public/CNAME`**

```
crisisclothing.com
```

- [ ] **Step 2: Create a favicon from a brand asset**

Run:
```bash
magick "$HOME/Library/CloudStorage/Dropbox/Crisis Clothing/Brand/Crisis-Clothing-300x300.png" \
  -background '#37c22b' -flatten -resize 64x64 public/favicon.ico
```
(If `magick` is unavailable, add any 64×64 `favicon.ico`.)

- [ ] **Step 3: Create `.github/workflows/deploy.yml`**

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

# Cancel superseded runs; only one deploy at a time.
concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v7
      - name: Build Astro site
        uses: withastro/action@v6
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v5
```

- [ ] **Step 4: Final build to confirm CNAME + favicon ship**

Run: `npm run build && test -f dist/CNAME && grep -qx 'crisisclothing.com' dist/CNAME && echo CNAME_OK`
Expected: `CNAME_OK` (the `public/` files are copied into `dist/`).

- [ ] **Step 5: Commit**

```bash
git add public/CNAME public/favicon.ico .github/workflows/deploy.yml
git commit -m "Add CNAME, favicon, and GitHub Pages deploy workflow"
```

---

### Task 8: Project README and content-authoring docs

**Files:**
- Create: `README.md`
- Create: `docs/adding-a-design.md`

**Interfaces:**
- Consumes: nothing.
- Produces: contributor-facing setup + "how to add a design" documentation.

- [ ] **Step 1: Create `README.md`** (keep under 16,000 characters — quick summary + setup + link to docs)

```markdown
# crisisclothing.com

The Crisis Clothing design gallery — a static [Astro](https://astro.build) site
deployed to GitHub Pages at [crisisclothing.com](https://crisisclothing.com).

Each design is a Markdown entry in `src/content/designs/`; the gallery and a
detail page per design are generated at build time.

## Develop

```bash
npm install
npm run dev      # local dev server
npm run build    # static build → dist/
npm run check    # type + content checks
npm test         # unit tests (Vitest)
```

## Add a design

See [docs/adding-a-design.md](docs/adding-a-design.md).

## Deploy

Pushing to `main` triggers `.github/workflows/deploy.yml`, which builds and
deploys to GitHub Pages. The custom domain is pinned by `public/CNAME`. DNS is
managed separately as code — see `infra/` and its plan.
```

- [ ] **Step 2: Create `docs/adding-a-design.md`**

```markdown
# Adding a design

1. Add the primary image to `src/content/designs/images/<slug>.<ext>`.
2. Create `src/content/designs/<slug>.md`:

   ```markdown
   ---
   title: Your Design Title
   releaseDate: 2025-01-15        # YYYY-MM-DD; drives gallery order
   image: ./images/<slug>.png
   # Optional extra images:
   # gallery:
   #   - ./images/<slug>-back.png
   # Optional purchase links (omit the block for none):
   links:
     - label: Buy on Etsy
       url: https://…
   # draft: true                  # hide from the gallery while WIP
   ---

   Markdown description here.
   ```

3. `npm run build` — the schema validates every field; a bad entry fails the build.
4. Commit and push; the deploy workflow publishes it.

The filename (minus `.md`) is the URL slug: `<slug>.md` → `/designs/<slug>/`.
```

- [ ] **Step 3: Verify README length**

Run: `wc -c README.md`
Expected: well under 16000.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/adding-a-design.md
git commit -m "Add README and content-authoring docs"
```

---

## Post-implementation (manual, by the repo owner)

These are not code tasks; they gate the *live* deploy and are documented for the operator:

1. Push the branch and open a PR; merge to `main`.
2. GitHub repo → Settings → Pages → Source = **GitHub Actions**.
3. Settings → Pages → Custom domain = `crisisclothing.com` (generates the Pages
   challenge TXT value used by the DNS plan). Leave "Enforce HTTPS" until DNS
   resolves.
4. Verify the site at the github.io URL / the Pages deployment URL before DNS cutover.
5. Execute the DNS plan (`docs/superpowers/plans/2026-09-16-crisisclothing-dns.md`).

## Self-review notes

- **Spec coverage:** content model (Task 3), gallery newest-first + drafts excluded (Tasks 4–5), detail page with links omitted when empty (Task 6), visual direction/loud palette + script wordmark (Tasks 2, 5, 6), CNAME + Action deploy (Task 7), README/docs (Task 8). DNS is a separate plan.
- **Draft visibility:** drafts are excluded from both the gallery (Task 5) and `getStaticPaths` (Task 6, via `sortedPublishedDesigns`), so draft detail pages are not built — matching the spec's "not built."
- **No placeholders / type consistency:** `sortedPublishedDesigns`/`formatReleaseDate` signatures match across Tasks 4–6; `DesignCard` props match its usage in Task 5.
