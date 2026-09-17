# crisisclothing.com — Design Gallery Site

**Date:** 2026-09-16
**Status:** Approved design, pending spec review
**Repo:** `The-North-West-Clothing/crisisclothing.com`

## Purpose

A very simple static website that showcases the designs Crisis Clothing has
created, as a gallery with a detail page per design. Each design has a release
date (to be backfilled), a description, and links to where it can be purchased.
Hosted on GitHub Pages at the custom apex domain `crisisclothing.com`, with DNS
managed as code via OpenTofu.

This is deliberately a starting point. Likely future upgrades (tags/collections,
per-design status/price, multi-image galleries) are anticipated in the schema
but not built now (YAGNI).

## Two components

1. **The website** — an Astro static site, built and deployed to GitHub Pages by
   a GitHub Action.
2. **DNS as code** — an OpenTofu configuration that creates and manages the
   `crisisclothing.com` Route 53 hosted zone, in a new dedicated `crisis-admin`
   AWS account, mirroring the established `nw-local-ops/infra` pattern.

The two are independent: the site can ship and be verified at the github.io URL
before DNS is cut over.

---

## Component 1 — Website (Astro)

### Stack and rationale

- **Astro**, static output, zero client JS by default. Chosen over hand-written
  HTML because designs are managed as *data* (one entry each), so the gallery
  and every detail page are generated — adding a design is adding one file, not
  copy-pasting a page. Chosen over plain-JSON-plus-JS because content collections
  give build-time schema validation (a malformed entry fails the build instead of
  silently shipping broken).
- Deployed to GitHub Pages via GitHub Actions.

### Content model — one collection, `designs`

Each design is a Markdown file at `src/content/designs/<slug>.md`. The slug (the
filename) is the URL segment and the stable identifier. Frontmatter is validated
by a Zod schema at build time:

| Field         | Type                     | Required | Notes |
|---------------|--------------------------|----------|-------|
| `title`       | string                   | yes      | Display name, e.g. "Storm Relief Hoodie" |
| `releaseDate` | date                     | yes      | Backfilled; drives gallery sort order |
| `image`       | `image()`                | yes      | Primary/hero; used as gallery thumbnail and detail hero |
| `gallery`     | `image()[]`              | no       | Additional shots; empty for now ("room to grow") |
| `links`       | `{ label, url }[]`       | no       | Purchase links; omit or empty = no purchase section |
| `draft`       | boolean (default false)  | no       | When true, hidden from the gallery and not built |

- **Description is the Markdown body**, not a frontmatter string — free formatting.
- `links[].url` is validated as a URL; `links[].label` is a non-empty string.
- `image()` is Astro's content-collection image helper: it optimizes and
  content-hashes each image at build time.

Source images live in `src/content/designs/images/` (co-located with content so
the `image()` helper resolves relative paths).

### Pages

- **`/` — gallery.** Responsive grid of `DesignCard`s (thumbnail, title, release
  date). Sorted **newest-first by `releaseDate`**. Drafts excluded.
- **`/designs/[slug]` — detail.** Built via `getStaticPaths()` over the
  collection. Shows hero image, title, release date, rendered Markdown
  description, the optional additional-image gallery, and purchase links as a row
  of labeled buttons. The purchase section is omitted entirely when a design has
  no links.

### Shared UI

- `src/layouts/BaseLayout.astro` — `<head>` (title, meta, favicon), site header
  (Crisis Clothing wordmark linking home) and footer, and shared styling per the
  Visual direction below.
- `src/components/DesignCard.astro` — one gallery card.

### Visual direction

Adapted from an observed reference aesthetic (not copied): a
**brutalist-editorial × airbrushed-Y2K × retro-computing** language that suits a
streetwear/apparel gallery. Documented here as direction, not pixel spec — real
values chosen at implementation and tuned to Crisis Clothing's own brand.

**Brand assets (existing):**

- **Logo:** a flowing **Spencerian/soda-fountain script wordmark** ("Crisis")
  with a sweeping swash underline. Source art at
  `~/Dropbox/Crisis Clothing/Brand/` (transparent PNG in white and navy; a
  300×300 and a profile-pic crop also exist). High-res (4068×2674).
- **Existing colorways / palette (never formalized, derived from the assets):**
  - Navy `#132452` (sampled from `Crisis_navy.png`)
  - White (reversed-out)
  - Green + yellow: vivid green field (~`#37C22B`) with bright yellow lettering
    (~`#F5E10A`) — approximate; exact-sample from a source file if formalizing.
- No preferred UI/body fonts yet.

**Type pairing principle:** the script wordmark is the brand's single ornate
signature — used for the logo/wordmark only. Everything else (headlines, body,
labels) uses a stark modern grotesque + monospace system, so the script stays
special and never competes with itself.

**Palette direction (to confirm):** anchor on the existing colorways rather than
inventing new ones. Two viable moods:
  - *Classic:* navy + off-white paper + charcoal text, with green or yellow as a
    single accent. Versatile, lets garment photography lead.
  - *Loud:* bold green/yellow full-bleed hero and section fields, navy/charcoal
    for text on light areas. Punchier, more streetwear.
  Default if unspecified: Classic (navy-anchored), with a bold accent, since it
  keeps product imagery dominant per the guardrails below.

**Principles:**

- **Type is the hero.** Oversized, tightly-tracked grotesque display headlines
  (Helvetica Now / Neue Haas Grotesk / Inter-tight family), near edge-to-edge,
  for section titles and the site wordmark. Body copy in a plain neutral sans.
  Small **uppercase, letter-spaced monospace "kicker" labels** above content
  blocks (e.g. a design's release date or a "PURCHASE" label).
- **Bold, saturated color fields over minimal-white.** High-contrast full-bleed
  sections rather than a timid all-white page. A restrained palette: one or two
  confident brand hues (to be set — Crisis Clothing's own), deep near-black
  charcoal for text, off-white paper. Airbrushed/gradient accents allowed but
  used sparingly so garment imagery stays the focus.
- **Print-production + retro-GUI motifs, as texture not gimmick.** Corner
  **crop/registration marks** framing the gallery grid; optional **1-bit
  dithered/halftone** treatment for section dividers or empty states; monospace
  detail strings (SKU, release date, edition) as fine print. These are accents;
  they must never compete with the design photography.
- **Editorial grid.** Generous whitespace, a real column grid, release dates and
  counts set as deliberate typographic elements.

**Guardrails (apparel-specific):**

- The **product images are the content** — every stylistic motif yields to the
  garment photography. On the gallery, cards are image-forward; type framing is
  secondary.
- Motifs are applied with restraint (a framing mark, a mono label), not layered
  all at once. Accessibility and legibility (contrast, focus states, tap targets)
  are non-negotiable and take precedence over any retro effect.
- Fonts loaded self-hosted or via a permitted provider; no layout shift.

### Repository layout

```
crisisclothing.com/
├── src/
│   ├── content/
│   │   ├── config.ts              # Zod schema for the `designs` collection
│   │   └── designs/
│   │       ├── <slug>.md          # one file per design
│   │       └── images/            # design source images
│   ├── layouts/BaseLayout.astro
│   ├── components/DesignCard.astro
│   └── pages/
│       ├── index.astro            # gallery
│       └── designs/[slug].astro   # detail
├── public/
│   └── CNAME                      # "crisisclothing.com" — pins custom domain
├── infra/                         # OpenTofu (Component 2)
├── .github/workflows/deploy.yml   # build + deploy to Pages
├── astro.config.mjs               # site: https://crisisclothing.com
└── package.json
```

`public/CNAME` is committed so every deploy re-asserts the custom domain
(a redeploy can otherwise drop the Pages custom-domain setting).

### Deploy workflow

`.github/workflows/deploy.yml`, triggered on push to `main`:

1. Checkout, install, `astro build` (via the official `withastro/action`).
2. Upload the built site as a Pages artifact and deploy with `actions/deploy-pages`.

Use latest stable major versions of all actions. Pages source is set to
"GitHub Actions" in repo settings (manual, one-time).

### Testing / verification

Astro has no default test runner and the logic here is thin. Verification is:

- `astro build` succeeds (schema validation catches malformed entries) — run in CI.
- `astro check` for type/content errors.
- At least one seed design entry (placeholder image + example links) so the
  gallery and a detail page render and can be eyeballed at the github.io URL
  before DNS cutover.

Note: the dev server is never booted by the assistant (project rule); rely on
build + check, and the user verifies visually in their own running server.

---

## Component 2 — DNS as code (OpenTofu)

Mirrors `nw-local-ops/infra` exactly in shape and conventions.

### Account

A **new dedicated `crisis-admin` AWS account**, created as a member account in
the existing AWS Organization. This matches the established account-per-entity
pattern (`audeos-admin`, `audeos-fm-admin`, `nw-local-admin`) and keeps Crisis
Clothing's billing and IAM blast radius isolated. The account topology is
independent of the (still-open) legal-entity structure decision and can be
re-parented under any OU later.

### Provider and backend conventions (from `nw-local-ops`)

- `required_version >= 1.10`; `hashicorp/aws ~> 6.0`.
- **S3 backend with native lockfile:** `use_lockfile = true`, `encrypt = true`,
  `profile` pinned as a literal (backend blocks cannot reference variables).
- New state bucket `crisis-clothing-tfstate` in the crisis account, **created by
  hand once** (bootstrap) — the config deliberately does not manage its own state
  store (same rationale documented in `nw-local-ops`: a config that manages its
  own state store is a `tofu destroy` trap and a circular bootstrap).
- `provider "aws"` pinned with `profile = var.aws_profile` (the crisis account's
  SSO profile) and `default_tags` = `{ Project = "crisisclothing.com",
  Environment = "production", ManagedBy = "opentofu", Repo =
  "The-North-West-Clothing/crisisclothing.com" }`.

### Resources created

- `aws_route53_zone.primary` — `crisisclothing.com`.
- **Apex A records** → GitHub Pages IPs:
  `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
- **`www` CNAME** → `the-north-west-clothing.github.io`.
- **GitHub Pages custom-domain challenge TXT** —
  `_github-pages-challenge-the-north-west-clothing`, value provided by GitHub when
  the custom domain is added in repo settings. Modeled as a variable and filled
  once.
- (Optional, later) org-level GitHub domain-verification TXT if org verification
  is enabled.

### The registration-account wrinkle (decision: approach A)

The `crisisclothing.com` domain **registration** currently lives in an existing
account (**to confirm at apply time** — likely `audeos-admin`), not the new
`crisis-admin` account. The hosted zone will be created in `crisis-admin`, so the
registrar must delegate to it.

**Chosen approach — A (repoint NS now, transfer later):**
create the zone in `crisis-admin`; then update the domain's four name-server
records (in whichever account holds the registration) to the new zone's NS.
Works immediately. Optionally transfer the domain registration into
`crisis-admin` later for tidiness (rejected as the *now* step because an AWS
domain transfer adds days), at which point an
`aws_route53domains_registered_domain` resource can manage delegation +
`auto_renew` + `transfer_lock` in one config, as `nw-local-ops` does.

### Manual, one-time operator steps (exact commands go in the plan)

1. Create the `crisis-admin` member account in the AWS Org; create an SSO profile
   for it locally.
2. Create the S3 state bucket `crisis-clothing-tfstate` in that account.
3. In GitHub repo settings: set Pages source = GitHub Actions; add custom domain
   `crisisclothing.com` (generates the challenge TXT value).
4. Fill the challenge TXT variable; `tofu init` + `tofu apply`.
5. Repoint the registrar's NS records (in the registration account) to the new
   zone's name servers.

---

## Out of scope (explicitly deferred)

- Tags / collections / categories, search, filtering.
- Per-design price or availability status.
- Multi-image galleries in the UI (schema leaves room; UI is single-hero for now).
- Any CMS or admin UI — entries are hand-authored Markdown.
- Transferring the domain registration into `crisis-admin` (later tidy-up).
- Resolving the legal-entity structure (separate track, with a CPA/attorney).

## Open items to confirm at implementation/apply time

- Which existing account holds the `crisisclothing.com` registration.
- The GitHub Pages challenge TXT value (available after adding the custom domain).
- Final GitHub Pages IP list (verify against GitHub's current published set).
