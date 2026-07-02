# AGENTS.md — <PROJECT>

<!--
  SKELETON — fill this in when you create a project from this template.
  This is the canonical, tool-agnostic, self-contained source of truth for any
  AI coding agent or human contributor (Claude Code, Codex, Cursor, Aider, Gemini
  CLI, …). CLAUDE.md imports this file and adds Claude-only notes — do NOT
  duplicate content between the two. Style: tables and command lists over prose;
  no changelogs (that's git / CLAUDE.local.md); link to docs/ for depth. Budget:
  150–300 lines. Delete these HTML comments as you fill each section.
-->

> Claude Code users: `CLAUDE.md` imports this file and adds a Claude-only section.
> Don't duplicate content from here into `CLAUDE.md`.

---

## What <PROJECT> is

<!--
  Purpose, deployment posture, and HARD non-goals. One tight paragraph. State
  what it is (self-hosted web app), who it's for (single user? household?), where
  it runs (Docker on a NAS behind a reverse proxy?), and the lines it will not
  cross. Non-goals are load-bearing — they let a new feature be refused.
-->

## Tech stack

<!-- A table. This template ships with: -->

| Layer | Technology |
|-------|------------|
| Framework | Next.js 16 (App Router, standalone output) + React 19, TypeScript strict |
| Runtime | Node 22 LTS (`.nvmrc`), npm |
| Database | SQLite via Drizzle ORM + better-sqlite3 (WAL, FKs on) |
| Styling | Tailwind CSS, hand-rolled components |
| Tests | Vitest (`test/`, fixtures in `test/fixtures/`) |
| Lint | ESLint 9 flat config, `--max-warnings 0` |
| Scheduling | node-cron, in-process, registered from `instrumentation.ts` (add when needed) |
| Deploy | Docker Compose on a self-hosted host (`scripts/deploy.sh`) |

## Commands

<!-- Copy-pasteable, one-line comments; flag anything that hits a live service. -->

```bash
npm install              # install deps (Node 22)
npm run dev              # dev server (http://localhost:3000) — scheduler off
npm run build            # production build (also part of the type gate)
npm start                # serve a production build
npm run lint             # eslint . --max-warnings 0  (matches CI)
npm run typecheck        # tsc --noEmit
npm test                 # vitest run

npm run db:push          # apply schema to the dev SQLite file
npm run db:generate      # generate a migration into drizzle/
npm run db:studio        # Drizzle Studio DB browser

./scripts/deploy.sh      # preflight → SSH to host → build → up → health poll
```

## Repo map

<!-- Annotated tree of src/. Prune/extend as the project grows. -->

```text
src/
├── app/                  # Next.js App Router (routes + layout)
│   ├── layout.tsx        # root layout
│   ├── page.tsx          # home page
│   └── health/route.ts   # public health endpoint (Docker healthcheck contract)
├── components/           # hand-rolled UI components
├── config/env.ts         # zod-validated process.env (single env entry point)
├── db/
│   ├── schema.ts         # SINGLE SOURCE OF TRUTH for the schema
│   ├── index.ts          # connection singleton (WAL, FKs)
│   └── migrate.ts        # boot-time migration runner (prod-gated)
├── instrumentation.ts    # boot: migrations + scheduler registration
└── proxy.ts              # auth gate (Next 16 middleware rename)
```

Path alias: `@/` → `src/`.

## Architecture in brief

<!--
  Data flow and the components an agent must NOT bypass. Draw the pipeline. Name
  the singletons/gates that all traffic must go through (the DB singleton, the
  auth proxy, any external-API client). Keep it to what an agent needs to avoid
  breaking invariants.
-->

## Database / storage

<!--
  Schema source of truth is src/db/schema.ts. Migration flow:
    edit schema.ts → `npm run db:generate` → review SQL in drizzle/ →
    `npm run db:push` (dev). Prod applies migrations on container boot
    (src/db/migrate.ts, prod-gated) — never hand-apply on prod.
  SQLite notes: no ALTER COLUMN; timestamps as ISO TEXT (`datetime('now')`);
  booleans as INTEGER (`{ mode: 'boolean' }`). List your key tables here.
-->

## Conventions

<!-- Rules that differ from language/framework defaults. Starting set: -->

- TypeScript strict, no `any`; `import type` for type-only imports.
- Server Components by default; add `'use client'` only for interactivity.
- Tailwind only, no inline styles; hand-rolled components over component libs.
- API routes: try/catch, validate bodies with zod `.safeParse()`, return a
  consistent JSON shape with accurate status codes.
- Next 16: route `params`/`searchParams` are Promises — `await` them.
  `proxy.ts` replaces `middleware.ts`.
- Conventional Commits; feature branches off `main` (branch protection on public repos).

## Critical gotchas

<!--
  The highest value-per-token section. Every incident that costs a session goes
  here, stated as a rule. Template starters (keep the ones that apply):
-->

- **Migrations run on container boot** (`src/db/migrate.ts`, prod-only; tracked
  in `__drizzle_migrations`). Dev DBs are `db:push`-created and have no journal,
  so the migrator is prod-gated — never pre-apply schema on prod.
- **DB connection is a singleton on `globalThis`** — Next standalone can load
  separate module instances for instrumentation vs route handlers. Import
  `getDb()` from `@/db`; never construct a second connection.
- **Clients/DB are server-only** — never import them from a `'use client'` component.
- **`proxy.ts`, not `middleware.ts`** (Next 16 rename). Auth gating lives there.
- **The scheduler is off in dev** unless `ENABLE_SCHEDULER=true`, so `npm run dev`
  never fires background jobs.

## Environment

<!--
  Env is read in src/config/env.ts (zod-validated). Copy `.env.example` →
  `.env.local` (dev); prod env lives on the host as `.env.production` (never
  committed). List required vs optional vars here — names only, NEVER values.
  Secret locations (not values) may go in CLAUDE.local.md.
-->
