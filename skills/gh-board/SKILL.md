---
name: gh-board
description: Read and write tickets on a GitHub Projects v2 board via the `board` CLI, where a ticket IS a GitHub issue plus its project item. Use when asked to write/edit/comment on a ticket, move a ticket's Status or set another board field, list what's on the board, or check what someone is working on. Each board has its own fields and options; `board fields` lists them with what each option means. Triggers on "ticket", "the board", "DevBoard", "project board", "move to <status>", "what's on the board", "file a ticket", "assign a ticket".
---

# gh-board

`board` is a CLI over **GitHub Projects v2 + Issues**. It delegates all auth and
transport to `gh`, so there are no tokens and no separate login.

```bash
board help      # full command list — read this instead of guessing flags
board fields    # live board fields, their options, and what each option means
```

If `board` is not on PATH, run `~/.dotfiles/tools/gh-board/board`.

## The one idea that matters

**A ticket is two GitHub objects presented as one.** Half of a ticket is a
GitHub issue (title, body, comments, labels, assignees, open/closed). The other
half is a *project item* holding the board-only fields (Status, plus whatever
else the board defines). They live in different places in GitHub's API;
`board` hides the seam.

Route by which half you're touching:

| You want to change | Half | Command |
|---|---|---|
| title, body, labels, assignees, milestone | issue | `board edit <ref>` |
| add a comment | issue | `board comment <ref>` |
| open / closed | issue | `board close` / `board reopen` |
| Status or another board field | project item | `board status` / `set` |
| create both at once | both | `board new` |

`board new` is the only command that does both: it creates the issue, adds it to
the board, and sets board fields in one call. `board view <ref>` reads both
halves and prints them together.

## Read the board, never hardcode it

Boards differ: one may use Inbox / Development / Done, another Triage / Ready /
Closed, and some have extra fields. Run `board fields` before setting a field on
a board you haven't read this session. It prints each option with its
description, which is where the board records what the option means (for
example, which status new tickets start in).

Option values are fuzzy-matched — emoji, case, and punctuation are ignored, so
`done` matches `✅ Done` and `dev` matches `🧪 Development`.

**Do not write the option list into any file.** It changes on the board without
warning. `board fields` is the only source of truth.

## `repo#N` is a CLI convenience, not a GitHub reference

Every command takes a ticket ref as a full issue URL, `owner/repo#N`, or
`repo#N` (owner taken from `BOARD_ORG`).

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

## Which board

The CLI is not tied to one board. `BOARD_ORG` (the owner, an organization or a
user) and `BOARD_PROJECT` (the project number) pick it; without them it falls
back to `board.config.json` next to the script. `repo#N` expands with
`BOARD_ORG` as the owner.

A repo that has its own board sets both in its `.claude/settings.json`, so every
`board` command in that repo targets it:

```json
"env": {"BOARD_ORG": "some-user", "BOARD_PROJECT": "1"}
```

`board fields` prints the project it resolved on its first line; check it if the
board looks wrong. For a one-off command against another board, prefix the
variables:

```bash
BOARD_ORG=some-org BOARD_PROJECT=7 board list
```

## Requirements

Node ≥ 23.6 (runs the TypeScript directly, no build step) and an authenticated
`gh` with `project`, `repo`, and `read:org` scopes.
