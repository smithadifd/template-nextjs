import type { Config } from 'drizzle-kit';

// Drizzle Kit config — used by `npm run db:generate` / `db:push` / `db:studio`.
// The runtime app never uses this file; the SQLite path is resolved in src/config/env.ts.
export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'sqlite',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? './data/app.db',
  },
} satisfies Config;
