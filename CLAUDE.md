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
