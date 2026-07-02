/**
 * Boot-time migration runner (prod-gated).
 *
 * Called once from src/instrumentation.ts on server startup. Applies any
 * migrations in drizzle/ that haven't been applied yet, tracked in
 * __drizzle_migrations.
 *
 * GOTCHA: this only runs in production (NODE_ENV=production). Dev databases are
 * created with `npm run db:push` and have no migration journal, so running the
 * migrator against a dev DB would fail with "table already exists". Never
 * pre-apply a migration by hand on prod — let the container's boot do it.
 */

import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import { env } from '@/config/env';
import { getDb } from './index';

export function runMigrations(): void {
  if (env.NODE_ENV !== 'production') {
    console.warn('[migrate] skipped — not production (dev uses `npm run db:push`)');
    return;
  }
  try {
    migrate(getDb(), { migrationsFolder: './drizzle' });
    console.log('[migrate] migrations applied');
  } catch (error) {
    console.error('[migrate] migration failed:', error);
    throw error;
  }
}
