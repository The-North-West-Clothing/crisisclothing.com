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
