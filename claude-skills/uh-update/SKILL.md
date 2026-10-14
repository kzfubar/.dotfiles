---
name: uh-update
description: Update the user harness in the current repo to the latest user-harness template, end to end. Runs the deterministic `uh update` merge, resolves any conflicts it leaves, runs scripts/verify, and opens a harness-only PR.
disable-model-invocation: true
argument-hint: "[repo path, default: current repo]"
---

# Update the user harness

One command for the whole update. `uh update` does the mechanical part: a three-way merge of every harness file
between the template this repo last installed (`.uh/base/`), the repo's copy, and the current template in
`~/projects/user-harness`. This skill wraps it: it prepares the branch, runs it, settles what needs judgment,
checks the result and opens the PR.

Work in the repo given as an argument, or the current one. Stop and report if it has no `.uh/` directory.

## 1. Prepare

- Stop if the repo has uncommitted changes in harness files (`AGENTS.md`, `CLAUDE.md`, `docs/agents/`, `.claude/`,
  `.uh/`, `scripts/verify`). Don't stash or commit them yourself.
- Check that `~/projects/user-harness` has no uncommitted changes under `src/user_harness/template`. If it has, say so:
  the update would install unreleased template changes. Continue only if the user confirms.
- Fetch, switch to an up-to-date default branch, and create the branch `uh-update-<YYYY-MM-DD>`.

## 2. Run the merge

Run `uh update --dry-run` and then `uh update`. Exit codes: 0 means done; 2 means conflicts were written; 1 means it
refused (read its message).

If it refuses because there is no `.uh/base/`, the repo was installed before `uh update` existed. Find the
user-harness commit it was installed from: the date the harness arrived
(`git log --diff-filter=A --format=%ad --date=iso -- .uh/harness-log.md`), then the last user-harness commit on or
before it (`git -C ~/projects/user-harness log --before=<date> -1 --format=%h`). Run
`uh update --dry-run --base-ref <commit>`, show the user the plan and the commit you picked, and run it for real
only once they agree.

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
  "now UH-nnn", because ids are never reused. If you're unsure whether two rows match, ask.

**`own`** files were added both here and in the template with different content. The repo's copy was kept and is
now tracked as a local change. Diff it against `.uh/base/<path>` and tell the user what the template version does
differently. Bring a template change in only if it is clearly a generic fix, and say so.

**`kept`** files changed here but were changed or dropped upstream. Report them; don't delete anything.

## 4. Check

- No conflict markers remain: `git grep -nE '^(<<<<<<<|=======|>>>>>>>)( |$)' -- AGENTS.md docs .claude .uh scripts`.
- Every changed `.json` file parses.
- `scripts/verify` passes. Show its result line. If it fails, fix what the update caused, and report anything else
  without fixing it.
- If the update changed `docs/agents/orchestration.md` or the SessionStart hook, say that the change takes effect
  from the next session.

## 5. Commit and open the PR

Commit everything the update touched, including `.uh/base/` and `.uh/manifest.json`, as one harness-only commit in
the repo's message style. Push the branch and open a PR. The body lists the actions from `uh update`, how each
conflict and `own` file was resolved, and the `scripts/verify` result line. Don't merge it.

End with the PR link and a short summary: what changed, what needed judgment, and anything left for the user.
