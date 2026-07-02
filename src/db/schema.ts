/**
 * Database schema — the SINGLE SOURCE OF TRUTH.
 *
 * Edit this file to change the schema, then:
 *   npm run db:generate   # writes a migration SQL file into drizzle/
 *   npm run db:push       # applies the schema to your dev SQLite file
 *
 * In production, migrations are applied on container boot (prod-gated) — see
 * src/db/migrate.ts and src/instrumentation.ts. Never hand-apply schema on prod.
 *
 * SQLite notes: no ALTER COLUMN; store timestamps as ISO TEXT (default
 * `datetime('now')`); store booleans as INTEGER with `{ mode: 'boolean' }`.
 */

import { sql } from 'drizzle-orm';
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';

/** Example table. Replace with your domain tables. */
export const items = sqliteTable('items', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  done: integer('done', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at')
    .notNull()
    .default(sql`(datetime('now'))`),
});

export type Item = typeof items.$inferSelect;
export type NewItem = typeof items.$inferInsert;
