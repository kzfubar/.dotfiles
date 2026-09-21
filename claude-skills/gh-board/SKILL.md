---
name: gh-board
description: Read and write tickets on a GitHub Projects v2 board via the `board` CLI, where a ticket IS a GitHub issue plus its project item. Use when asked to write/edit/comment on a ticket, move a ticket's Status (inbox, development, testing, bottlenecked, done), set Class or Lab Priority, list what's on the board, or check what someone is working on. Triggers on "ticket", "the board", "DevBoard", "move to testing", "what's on the board", "file a ticket", "assign a ticket".
---

# gh-board

`board` is a CLI over **GitHub Projects v2 + Issues**. It delegates all auth and
transport to `gh`, so there are no tokens and no separate login.

```bash
board help      # full command list — read this instead of guessing flags
board fields    # live board fields + their single-select options
```

If `board` is not on PATH, run `~/.dotfiles/tools/gh-board/board`.

## The one idea that matters

**A ticket is two GitHub objects presented as one.** Half of a ticket is a
GitHub issue (title, body, comments, labels, assignees, open/closed). The other
half is a *project item* holding the board-only fields (Status, Class, Lab
Priority). They live in different places in GitHub's API; `board` hides the seam.

Route by which half you're touching:

| You want to change | Half | Command |
|---|---|---|
| title, body, labels, assignees, milestone | issue | `board edit <ref>` |
| add a comment | issue | `board comment <ref>` |
| open / closed | issue | `board close` / `board reopen` |
| Status, Class, Lab Priority | project item | `board status` / `class` / `priority` / `set` |
| create both at once | both | `board new` |

`board new` is the only command that does both: it creates the issue, adds it to
the board, and sets board fields in one call. `board view <ref>` reads both
halves and prints them together.

## Never hardcode field values

Status/Class/Priority are fuzzy-matched — emoji, case, and punctuation are
ignored, so `done` matches `✅ Done` and `dev` matches `🧪 Development`.

**Do not write the option list into any file.** It changes on the board without
warning. `board fields` is the only source of truth; run it when you need to know
what's valid.

## `repo#N` is a CLI convenience, not a GitHub reference

Every command takes a ticket ref as a full issue URL, `owner/repo#N`, or
`repo#N` (org filled in from config).

`repo#N` works **only as a shell argument to `board`**. GitHub does not parse it.
Writing `controllers#1` inside an issue body, comment, or PR description produces
plain text — no link, no cross-reference, no auto-close. In anything GitHub
renders, use `#N` (same repo) or `owner/repo#N`.

For PR-to-issue linking specifically, see the `gh-pr-linking` skill.

## Multi-line and generated bodies

Do not try to escape newlines into `--body`. Use stdin or a file:

```bash
board comment controllers#1 --body -   <<'EOF'
Multi-line
comment body.
EOF

board new --repo controllers --title "..." --body-file /tmp/body.md
```

## Targeting a different board

The CLI is not tied to one board. It reads `board.config.json` (`org`,
`projectNumber`) next to the script, overridable per-invocation:

```bash
BOARD_ORG=some-org BOARD_PROJECT=7 board list
```

## Requirements

Node ≥ 23.6 (runs the TypeScript directly, no build step) and an authenticated
`gh` with `project`, `repo`, and `read:org` scopes.
