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
managed separately as code in an OpenTofu configuration (planned).
