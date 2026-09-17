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
