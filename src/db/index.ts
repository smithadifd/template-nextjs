/**
 * Database connection singleton (WAL mode, foreign keys on).
 *
 * Hoisted onto globalThis because Next standalone can load separate module
 * instances for instrumentation vs route handlers, and we want ONE connection.
 * Server-only — never import this from a `'use client'` component.
 */

import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { env } from '@/config/env';
import * as schema from './schema';

type Db = ReturnType<typeof drizzle<typeof schema>>;

const globalForDb = globalThis as unknown as { __db?: Db };

function createDb(): Db {
  mkdirSync(dirname(env.DATABASE_URL), { recursive: true });
  const sqlite = new Database(env.DATABASE_URL);
  sqlite.pragma('journal_mode = WAL');
  sqlite.pragma('foreign_keys = ON');
  return drizzle(sqlite, { schema });
}

export function getDb(): Db {
  if (!globalForDb.__db) {
    globalForDb.__db = createDb();
  }
  return globalForDb.__db;
}
