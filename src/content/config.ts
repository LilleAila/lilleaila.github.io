import { defineCollection, z } from "astro:content";

const blog = defineCollection({
  type: "content",
  // Type-check frontmatter using a schema
  schema: z.object({
    title: z.string(),
    description: z.string(),
    // Transform string to Date object
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    //heroImage: z.string().optional(),
    tags: z.array(z.string()),
    draft: z.boolean().optional(),
  }),
});

const projects = defineCollection({
  type: "content",
  schema: z.object({
    // Same as blog (i don't think it's possible to extend)
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.string()),
    draft: z.boolean().optional(),
    // Extra values
    //heroImage: z.string().optional(), // maybe later
    repoUrl: z.string().optional(),
    demoUrl: z.string().optional(),
  }),
});

export const collections = { blog, projects };
