# template-nextjs

A GitHub **template repository** for a self-hosted Next.js app — the "Family 1"
scaffold in Andrew's portfolio standards (Next.js 16 App Router + React 19,
TypeScript strict, SQLite + Drizzle, Docker Compose deploy). It builds green out
of the box; you fill in the domain.

## Use this template

```bash
# Create a new repo from this template (works on private templates you own):
gh repo create <your-repo> --template smithadifd/template-nextjs --private --clone
cd <your-repo>

nvm use            # Node 22 (from .nvmrc)
npm install
npm run dev        # http://localhost:3000
```

Then parameterize:

1. **`package.json`** — set `name`.
2. **Context files** — fill the `AGENTS.md` skeleton (10 sections), and replace
   `<PROJECT>` in `CLAUDE.md` and `CLAUDE.local.md.example`.
3. **`src/db/schema.ts`** — replace the example `items` table with your domain.
4. **`src/config/env.ts`** — add your env vars to the zod schema.
5. **`src/proxy.ts`** — wire in real auth (the template stub lets everything through).
6. **`.env.example`** / **`.deploy.env.example`** — copy to the gitignored real
   files and fill in values (never commit secrets).

## What's included

| Area | Files |
|------|-------|
| App | `src/app/` (layout, page, `health/route.ts`), `src/components/` |
| Config | `src/config/env.ts` (zod-validated), `.nvmrc`, `.editorconfig`, `tsconfig.json`, `eslint.config.mjs` |
| Database | `src/db/` (schema SSOT + connection singleton + boot-time prod-gated migrations), `drizzle.config.ts` |
| Boot | `src/instrumentation.ts` (migrations + scheduler stub), `src/proxy.ts` (auth-gate stub) |
| Tests | `test/` (one Vitest spec + fixture), `vitest.config.ts` |
| CI | `.github/workflows/ci.yml` (lint → typecheck → test → build), `deploy.yml` (manual stub) |
| Docker | `docker/Dockerfile` (standalone), `docker-compose.yml`, `docker-compose.prod.yml` |
| Deploy | `scripts/deploy.sh` (preflight → SSH → compose → health poll; parameterized) |
| Meta | `LICENSE` (MIT), `.github/FUNDING.yml`, `.github/dependabot.yml` |

## Scripts

```bash
npm run dev        # dev server
npm run build      # production build
npm start          # serve a production build
npm run lint       # eslint . --max-warnings 0
npm run typecheck  # tsc --noEmit
npm test           # vitest run
npm run db:push    # apply schema to dev SQLite
npm run db:generate  # generate a migration
```

## Deploy

Self-hosted Docker Compose over SSH. Configure `.deploy.env` (copy from
`.deploy.env.example`), put `.env.production` on the host, then:

```bash
./scripts/deploy.sh   # preflight → SSH → build → up → health poll
```

Migrations apply on container boot (prod-gated) — never pre-apply on prod.

## License

MIT — see [LICENSE](LICENSE).
