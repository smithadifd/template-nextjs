/**
 * Zod-validated environment configuration.
 *
 * Every process.env read the app depends on goes through here so that:
 *   - required vars are validated once at import time (fail fast, clear error),
 *   - optional vars get sensible defaults,
 *   - the rest of the codebase imports typed `env.*` instead of raw strings.
 *
 * Add your app's vars to the schema below. Never put secret *values* here —
 * only the schema. Values come from .env.local (dev) / .env.production (prod),
 * both gitignored.
 */

import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),

  // Path to the SQLite database file. In Docker this points at the mounted
  // data volume (e.g. /app/data/app.db); in dev it defaults under ./data.
  DATABASE_URL: z.string().default('./data/app.db'),

  // Turn the in-process scheduler on. Off by default so `npm run dev` never
  // fires background jobs; production boot sets NODE_ENV=production which also
  // enables it (see src/instrumentation.ts).
  ENABLE_SCHEDULER: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),

  // Example of a secret read from the environment (never committed).
  // Mark it optional in the template; make it required for your real app.
  AUTH_SECRET: z.string().optional(),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment configuration:', z.treeifyError(parsed.error));
  throw new Error('Invalid environment configuration — see logged issues above.');
}

export const env = parsed.data;
export type Env = typeof env;
