---
name: uh-update
description: Update the user harness in the current repo to the latest user-harness template, end to end, installing it first with `uh init` if the repo has none. Runs the deterministic `uh update` merge, resolves any conflicts it leaves, runs scripts/verify, and opens a harness-only PR.
disable-model-invocation: true
argument-hint: "[repo path, default: current repo]"
---

# Update the user harness

One command for the whole update. `uh update` does the mechanical part: a three-way merge of every harness file
between the template this repo last installed (`.uh/base/`), the repo's copy, and the current template in
`~/projects/user-harness`. This skill wraps it: it prepares the branch, runs it, settles what needs judgment,
checks the result and opens the PR.

Work in the repo given as an argument, or the current one. If it has no `.uh/` directory there is no harness to
update: install it instead (section 0), then stop, because an update straight after an install has nothing to do.

## Open questions

Some decisions belong to the user. Collect them first, then ask them together with the AskUserQuestion tool,
before writing anything: up to four questions per call, the recommended option first and marked "(Recommended)".
Don't ask them as plain text, and don't guess an answer to keep going. Common ones:

- **No git repository.** Options: run `git init` here (Recommended), or stop.
- **No GitHub remote** (`git remote` is empty, or `gh repo view` fails). Options: create a private repo with
  `gh repo create <name> --private --source . --remote origin` (Recommended), create a public one, or continue
  locally: commit on the branch and skip the push and PR.
- **No project board.** The repo's `.claude/settings.json` has no `BOARD_ORG` / `BOARD_PROJECT` in `env` (see
  the `gh-board` skill). Options: skip for now, create one with `gh project create --owner <owner> --title <repo>` and
  link it with `gh project link <number> --owner <owner> --repo <repo>`, or use an existing board (the user
  gives owner and number under "Other"). Write the chosen pair into the repo's `.claude/settings.json` `env`; the
  update commit carries it.
- **Autonomy level** (`docs/agents/orchestration.md`, UH-021): how much the main session may do without asking. On
  an install, always ask; options 1 (Recommended: asks before merging and before design decisions with notable
  tradeoffs), 2 (merges its own PRs once verify and CI pass), 3 (also settles notable design decisions itself after
  prior-art research and a plan review). On an update, ask only if the repo's `.claude/settings.json` `env` has no
  `UH_AUTONOMY`: options keep the default of 1 (Recommended), or set 2 or 3. Write a chosen level into that `env`;
  the update commit carries it.
- **Uncommitted template changes** in `~/projects/user-harness` (section 1).
- **The base commit** for an install that predates `.uh/base/` (section 2).
- **An uncertain `HL-` to `UH-` match** (section 3).

Ask about the repo and remote before anything else; the board question needs the remote's owner. A question that
only arises later (a conflict that needs judgment) is asked the same way when it arises.

## 0. Install if there is no harness

Settle the open questions above first: the repository, the remote, the board and the autonomy level.

- If the repo has no commits yet, make an empty initial commit on the default branch (`main` unless the user says
  otherwise) and push it, so the install can go through a PR like any other change.
- Create the branch `uh-init-<YYYY-MM-DD>` and run `uh init --autonomy <level>` with the level the user chose. It
  refuses if harness files already exist; report the clashes and stop rather than passing `--force`.
- Run `scripts/verify`. It should pass and report "no behavioural checks". Show its result line.
- Commit everything `uh init` wrote, including `.uh/base/` and `.uh/manifest.json`, as one harness-only commit in
  the repo's message style. Push, and open a PR labelled `uh-bootstrap` (create the label with
  `gh label create uh-bootstrap` if the repo lacks it). Merge it or not as section 5 says. Without a remote, stop
  after the commit.
- End with the PR link and the next steps `uh init` prints: fill `.uh/verify.toml`, grow `AGENTS.md` from observed
  failures, and protect `main` (require PRs and the `verify` check).

## 1. Prepare

- Stop if the repo has uncommitted changes in harness files (`AGENTS.md`, `CLAUDE.md`, `docs/agents/`, `.claude/`,
  `.uh/`, `scripts/verify`). Don't stash or commit them yourself.
- Check that `~/projects/user-harness` has no uncommitted changes under `src/user_harness/template`. If it has, say so:
  the update would install unreleased template changes. Ask whether to continue.
- Settle the open questions, then fetch, switch to an up-to-date default branch, and create the branch
  `uh-update-<YYYY-MM-DD>`.

## 2. Run the merge

Run `uh update --dry-run` and then `uh update`. Exit codes: 0 means done; 2 means conflicts were written; 1 means it
refused (read its message).

If it refuses because there is no `.uh/base/`, the repo was installed before `uh update` existed. Find the
user-harness commit it was installed from: the date the harness arrived
(`git log --diff-filter=A --format=%ad --date=iso -- .uh/harness-log.md`), then the last user-harness commit on or
before it (`git -C ~/projects/user-harness log --before=<date> -1 --format=%h`). Run
`uh update --dry-run --base-ref <commit>`, show the user the plan and the commit you picked, and ask whether to run
it for real.

## 3. Resolve what it leaves

The output lists one action per file. `add`, `update`, `merge` and `remove` need nothing more than review.

**`conflict`** files have `<<<<<<< yours` / `=======` / `>>>>>>> new template` markers. Resolve each one:
- Harness machinery (hooks, `bin/`, `lib/`): take the template's version and re-apply a local change only if it is
  project-specific (paths, names, settings). Say which local changes you kept.
- Project-owned text (`AGENTS.md`, `docs/agents/`, `verify.toml`, agent definitions): keep the project's content and
  bring in the template's structural changes.
- One home per rule. If the template moved a rule to another file (for example from `AGENTS.md` into
  `docs/agents/orchestration.md`), move the repo's copy of that rule too. Don't leave it in both places.
- `.uh/harness-log.md`: keep every row from both sides. Template rows use `UH-nnn` ids and the project's own rows
  use `HL-nnn`, so the two never collide.
- A project `HL-` row that is really a template row gets the template's id. This covers older installs, which
  numbered the template's rows `HL-001` and up, and features the project built under its own id before the
  template adopted them. Same failure and same mechanism counts as a match. For each match, change the id in every
  `<!-- HL-nnn -->` comment to the `UH-` id. Keep the old `HL-` row, marked `removed`, with the change column reading
  "now UH-nnn", because ids are never reused. If you're unsure whether two rows match, ask (see Open questions).

**`own`** files were added both here and in the template with different content. The repo's copy was kept and is
now tracked as a local change. Diff it against `.uh/base/<path>` and tell the user what the template version does
differently. Bring a template change in only if it is clearly a generic fix, and say so.

**`kept`** files changed here but were changed or dropped upstream. Report them; don't delete anything.

**`retire`** lines name functionality the harness has retired (from `src/user_harness/retired.toml` in the
user-harness package); `uh update` already removed its retired `.gitignore` lines. The notices under
`Retired functionality:` name leftover paths that still exist and steps outside the repo (for example on this
machine). Don't delete leftover paths or act on the notices yourself: copy them into the PR body for the user, since
leftovers are often data or committed history, and machine-level steps are the user's.

## 4. Check

- No conflict markers remain: `git grep -nE '^(<<<<<<<|=======|>>>>>>>)( |$)' -- AGENTS.md docs .claude .uh scripts`.
- Every changed `.json` file parses.
- `scripts/verify` passes. Show its result line. If it fails, fix what the update caused, and report anything else
  without fixing it.
- If the update changed `docs/agents/orchestration.md` or the SessionStart hook, say that the change takes effect
  from the next session.

## 5. Commit and open the PR

Commit everything the update touched, including `.uh/base/` and `.uh/manifest.json`, as one harness-only commit in
the repo's message style. Push the branch and open a PR (without a remote, stop after the commit). The body lists
the actions from `uh update`, how each conflict and `own` file was resolved, the retirement notices word for word,
and the `scripts/verify` result line.

Whether to merge follows the repo's autonomy level: `UH_AUTONOMY` in `.claude/settings.local.json`, else
`.claude/settings.json`, else 1 (the level this PR sets, if it changes it, applies from the next PR). At level 1,
don't merge; ask the user. At 2 or 3, merge once `scripts/verify` and the PR's CI pass, unless the update raised
something that needs the user: an unresolved question, a conflict you resolved by judgment that they should see, or
a retirement notice that asks them to act. Never merge past a failing or missing check.

End with the PR link and a short summary: what changed, what needed judgment, and anything left for the user.
