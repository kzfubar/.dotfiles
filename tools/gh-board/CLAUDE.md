# gh-board

A single-file CLI for reading and writing a GitHub Projects v2 board and the
issues that back it. This repo is the *implementation*; if you're here, you're
editing the tool, not using it.

> **User-facing docs live in the `gh-board` skill**
> (`~/.claude/skills/gh-board/SKILL.md`), and the command reference lives in the
> `HELP` string in `board.ts`. Don't re-document usage here — that's what caused
> this file to drift out of sync before. Behaviour change → update `HELP` and the
> skill.

## Files

- `board.ts` — the entire implementation (~650 lines, no dependencies)
- `board` — bash wrapper so `./board ...` works from any cwd
- `board.config.json` — default `org` + `projectNumber`
- `package.json` — `npm run board -- <args>`

## Design constraints

Two properties are load-bearing; preserve them.

**All auth and transport go through `gh`.** Every network call is
`execFileSync("gh", ...)` (`board.ts:42`), including GraphQL via `gh api graphql`
(`board.ts:56`). No tokens, no HTTP client, no auth code in this repo. Don't
introduce a direct API client.

**No build step.** It runs on Node ≥ 23.6 via native TypeScript type-stripping,
so keep to syntax that strips cleanly — no enums, no decorators, no namespaces,
no `experimental` type-directed emit.

## Where the complexity is

Everything else is a thin pass-through to `gh issue` / `gh project`. The parts
worth understanding before changing:

- `getProject` / `findField` / `setItemField` (`board.ts:77-258`) — Projects v2
  writes need `projectId` + `itemId` + `fieldId` + `singleSelectOptionId`, so
  every field write is a schema query followed by a GraphQL mutation. The schema
  is cached in `_project` for the process lifetime.
- `findOption` (`board.ts:117`) — fuzzy-matches single-select values by stripping
  everything but `[a-z0-9]`, which is what lets `done` resolve `✅ Done`.
- `parseRef` (`board.ts:142`) — accepts issue URL, `owner/repo#N`, or `repo#N`.
  The bare `repo#N` form is CLI-only; it is not valid GitHub reference syntax.
- `cmdNew` (`board.ts:416`) — the only command spanning both halves: creates the
  issue, adds it to the board, then sets board fields.

## Testing a change

There's no test suite; it's exercised against the live board. Read-only commands
are safe to run freely:

```bash
./board fields
./board list --json
./board view <repo>#<N> --json
```

For write paths, prefer a scratch issue over a real ticket.
