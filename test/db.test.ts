import Database from 'better-sqlite3';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { getTableName, is, Table } from 'drizzle-orm';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as schema from '@/db/schema';

const connections = new Set<Database.Database>();
const globalForDb = globalThis as unknown as { __db?: { $client: Database.Database } };
let directory: string;
let databasePath: string;

// Dynamic imports below reload env and the singleton only after each case's env stubs.
beforeEach(() => {
  vi.resetModules();
  delete globalForDb.__db;
  directory = mkdtempSync(join(tmpdir(), 'template-nextjs-db-'));
  databasePath = join(directory, 'nested', 'app.db');
  vi.stubEnv('DATABASE_URL', databasePath);
  vi.stubEnv('NODE_ENV', 'production');
  vi.spyOn(console, 'log').mockImplementation(() => {});
  vi.spyOn(console, 'warn').mockImplementation(() => {});
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  if (globalForDb.__db) connections.add(globalForDb.__db.$client);
  try {
    for (const connection of connections) {
      if (connection.open) connection.close();
    }
  } finally {
    connections.clear();
    delete globalForDb.__db;
    vi.restoreAllMocks();
    vi.doUnmock('better-sqlite3');
    vi.unstubAllEnvs();
    vi.resetModules();
    rmSync(directory, { recursive: true, force: true });
  }
});

async function connect() {
  const { getDb } = await import('@/db');
  const db = getDb();
  connections.add(db.$client);
  return db;
}

function journal(connection: Database.Database) {
  return connection.prepare(
    'SELECT hash, created_at FROM __drizzle_migrations ORDER BY created_at',
  ).all();
}

describe('runMigrations', () => {
  it('applies every production migration and leaves a second run unchanged', async () => {
    const { runMigrations } = await import('@/db/migrate');
    runMigrations();
    const { $client: connection } = await connect();
    const metadata = JSON.parse(readFileSync('drizzle/meta/_journal.json', 'utf8')) as {
      entries: { tag: string; when: number }[];
    };
    const expectedJournal = metadata.entries.map(({ tag, when }) => ({
      hash: createHash('sha256')
        .update(readFileSync(join('drizzle', `${tag}.sql`)))
        .digest('hex'),
      created_at: when,
    }));
    expect(expectedJournal).not.toEqual([]);
    expect(journal(connection)).toEqual(expectedJournal);
    const tables = connection.prepare("SELECT name FROM sqlite_master WHERE type = 'table'")
      .all() as { name: string }[];
    for (const table of Object.values(schema).filter((value) => is(value, Table))) {
      expect(tables).toContainEqual({ name: getTableName(table) });
    }
    connection.prepare('INSERT INTO items (name) VALUES (?)').run('survives migration rerun');
    const snapshot = connection.serialize();

    expect(() => runMigrations()).not.toThrow();

    expect(journal(connection)).toEqual(expectedJournal);
    expect(connection.serialize()).toEqual(snapshot);
  });

  it('logs and rethrows a production migration failure', async () => {
    const { $client: connection } = await connect();
    connection.exec('CREATE TABLE items (id INTEGER PRIMARY KEY)');
    const { runMigrations } = await import('@/db/migrate');

    const attempt = vi.fn(runMigrations);
    expect(attempt).toThrow(/Failed to run the query/);
    expect(console.error).toHaveBeenCalledTimes(1);
    const loggedError = vi.mocked(console.error).mock.calls[0][1];
    expect(loggedError).toBeInstanceOf(Error);
    expect(console.error).toHaveBeenCalledWith('[migrate] migration failed:', loggedError);
    expect(loggedError).toBe(attempt.mock.results[0].value);
    expect(loggedError).toMatchObject({
      cause: { message: expect.stringMatching(/table [`"]?items[`"]? already exists/) },
    });
    expect(journal(connection)).toEqual([]);
  });

  it.each(['development', 'test'] as const)(
    'does not open or migrate a database in %s and warns once',
    async (environment) => {
      vi.stubEnv('NODE_ENV', environment);
      const { runMigrations } = await import('@/db/migrate');

      runMigrations();

      expect(existsSync(databasePath)).toBe(false);
      expect(globalForDb.__db).toBeUndefined();
      expect(console.warn).toHaveBeenCalledTimes(1);
      expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('not production'));
      const { $client: connection } = await connect();
      expect(connection.prepare(
        "SELECT name FROM sqlite_master WHERE name = '__drizzle_migrations'",
      ).all()).toEqual([]);
    },
  );
});

describe('getDb', () => {
  it('creates the missing folder and reuses one connection across module instances', async () => {
    expect(existsSync(dirname(databasePath))).toBe(false);
    const first = await connect();
    const second = await connect();
    expect(second).toBe(first);
    expect(existsSync(dirname(databasePath))).toBe(true);
    expect(existsSync(databasePath)).toBe(true);

    vi.resetModules();
    const reloaded = await connect();
    expect(reloaded).toBe(first);
    expect(reloaded.$client).toBe(first.$client);
  });

  it('uses WAL journal mode', async () => {
    const { $client: connection } = await connect();
    expect(connection.pragma('journal_mode', { simple: true })).toBe('wal');
  });

  it('enables and enforces foreign keys', async () => {
    // This SQLite build defaults to FK enforcement; start a real connection OFF
    // so the test proves getDb enables it rather than inheriting driver defaults.
    vi.doMock('better-sqlite3', () => ({
      default: class extends Database {
        constructor(filename: string) {
          super(filename);
          this.pragma('foreign_keys = OFF');
          connections.add(this);
        }
      },
    }));
    const { $client: connection } = await connect();
    expect(connection.pragma('foreign_keys', { simple: true })).toBe(1);
    // The application schema has no foreign keys; use connection-local temp tables.
    connection.exec(`
      CREATE TEMP TABLE parents (id INTEGER PRIMARY KEY);
      CREATE TEMP TABLE children (parent_id INTEGER REFERENCES parents(id));
      INSERT INTO parents (id) VALUES (1);
    `);
    const insert = connection.prepare('INSERT INTO children (parent_id) VALUES (?)');
    insert.run(1);
    expect(() => insert.run(2)).toThrow('FOREIGN KEY constraint failed');
    expect(connection.prepare('SELECT parent_id FROM children').all()).toEqual([{ parent_id: 1 }]);
  });
});
