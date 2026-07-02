# CLAUDE.md — <PROJECT> (Claude Code)

@AGENTS.md

Everything about <PROJECT> — stack, commands, repo map, architecture,
conventions, and the critical gotchas — lives in the imported
[`AGENTS.md`](AGENTS.md). It is tool-agnostic and self-contained; read it first.
Personal/session config lives in the gitignored `CLAUDE.local.md` — read it
first if it exists (deploy details, URLs, secret locations, session log).

## Notes for Claude

- Run a fresh-eyes review (`/review` or the `reviewer` agent) on the diff before
  declaring work done; apply mechanical fixes silently, surface real questions.
- Doc updates (AGENTS.md, README, plans) ship in the same PR as the code change.
- Conventional Commits; never auto-push; confirm before destructive ops.
  No emojis unless asked.

## End-of-session workflow

1. **Branch** off `main` (`feat/…`, `fix/…`) — branch protection, no direct pushes.
2. **Commit** staged files with a Conventional Commit message.
3. **Push** `git push -u origin <branch>`, then `gh pr create`.
4. **CI** `gh run watch <run-id> --exit-status` — wait for green.
5. **Merge** `gh pr merge <n> --squash --delete-branch`; then `git checkout main && git pull`.
6. **Deploy** after main CI is green: `./scripts/deploy.sh`.
7. **Migrations** apply on container boot — never pre-apply on prod.
8. **Docs** update AGENTS.md / this file / CLAUDE.local.md session log in the same PR.
