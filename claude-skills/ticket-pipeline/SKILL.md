---
name: ticket-pipeline
description: Turn a planned body of work into tickets in a project's own ticketing pipeline and, if the user decides, develop them through the project's dev pipeline, or directly when it has none. Discovers the tracker (GitHub Projects board, GitHub or GitLab issues, Jira or Linear, a task file) and the dev workflow (user harness orchestration, documented workflow, board and PR conventions), confirms both with the user, files tickets only after the user approves the list, then develops them in dependency order with acceptance commands as the definition of done. Used by scaffold-webapp and scaffold-observability; also use directly when asked to file a plan as tickets, break work into tickets, or work through a set of tickets. Triggers on "file these as tickets", "break this into tickets", "work through the tickets", "develop the tickets".
---

# ticket-pipeline

Takes a plan that is already agreed with the user and moves it through the project's own
pipeline: tracker first, then development. It never decides *what* to build; the calling skill
or the user does. It decides *how the work moves*, following the project's conventions.

## Inputs

The caller (a skill such as `scaffold-webapp` or `scaffold-observability`, or the user) provides:

- **Plan doc:** the path of the project doc that records the decisions (for example
  `docs/stack.md`), with a table that has a Ticket column for this skill to fill in.
- **Draft tickets,** in dependency order, each with:
  - **Title**
  - **Context:** one paragraph, plus a link to the plan doc section
  - **Scope:** what to build, with file paths, tools, versions and reference sections
  - **Acceptance:** commands that prove it works, and their expected output
  - **Depends on:** the tickets that must land first
- **Presets** (optional): named subsets to offer when asking what to develop, such as "level-1 set".
- **Confirm-before** (optional): tickets that act outside the repo (deploying, sending data to a
  shared service, sending real email). Each of these needs its own confirmation before it starts.

When used directly without a caller, build these inputs with the user first.

## 1. Find the ticketing pipeline

Look in this order and use the first that is clearly the project's own:

1. The project's `CLAUDE.md` or `AGENTS.md`, or the harness docs (`.uh/`, `docs/agents/`), naming a board or tracker.
2. `BOARD_ORG` and `BOARD_PROJECT` in `.claude/settings.json`: a GitHub Projects board, written
   through the on-demand `gh-board` skill (read `~/.skills/gh-board/SKILL.md` first).
3. A GitHub remote with issues in use (`gh issue list --limit 5`) or a linked project
   (`gh project list`), or a GitLab remote (`glab`).
4. Jira or Linear keys (`ABC-123`) in commit messages, branch names or PR templates.
5. A tracking file in the repo (`TODO.md`, `ROADMAP.md`, `docs/tasks/`).

Confirm the pipeline with the user, even when it seems obvious. If there is none, offer GitHub
issues on the repo, or a checklist file next to the plan doc. Before writing anything, read the
pipeline's conventions (issue templates, labels, board fields and statuses, how dependencies are
linked) and follow them.

## 2. Confirm and file

Adapt the draft tickets to the tracker's style. Split any ticket too big for one PR; merge any
too small to review on its own. Show the user the complete list (titles, dependencies, one-line
scope each) and ask for changes. File nothing until they confirm.

Then create the tickets, link dependencies the way the tracker does, write each ticket's link
into the plan doc's Ticket column, and report the links in order.

## 3. Decide whether to develop

Ask whether to develop now, and which tickets: all, a preset, or a chosen list. In the same
question, settle how work lands. That is the pipeline's own way if one exists; otherwise commits
on a branch, a PR, or uncommitted changes for review. If the user says no, go to step 6.

## 4. Find the dev pipeline

Find how work normally moves from ticket to merged code:

- **User harness** (`.uh/`, `docs/agents/orchestration.md`): follow it exactly:
  - a worktree and branch per feature
  - `testwriter` first, then `coder`
  - a `Paths:` line and a `Ticket: #N` line in every subagent prompt
  - `scripts/verify`, friction entries, and a PR per ticket

  The main session orchestrates and does not edit `src/` or `tests/` itself.
- **Documented workflow:** steps in `CLAUDE.md` or `AGENTS.md`, or a ticket command or skill in
  `.claude/`. Use it as written.
- **Board and PR conventions:** move each ticket through the board's statuses as work starts and
  lands (`~/.skills/gh-board/SKILL.md`). Link each PR so merging closes its ticket (`gh-pr-linking`). Let CI run on
  each PR.

Tell the user which pipeline you found and how you'll drive it before starting. If there is none,
develop directly:
1. Branch first if on the default branch.
2. Implement one ticket at a time.
3. Run its acceptance commands and the project's own checks, and show their output.
4. Land it the way the user chose.

## 5. Develop

- Work in dependency order. Run independent tickets in parallel only where the pipeline allows it
  (separate worktrees, no overlapping paths).
- A ticket is done when its acceptance commands pass, with the output shown. Never mark one done
  because the code looks right.
- After each ticket lands, update its row in the plan doc and its status in the tracker.
- Stop and ask before any **confirm-before** ticket starts.
- Also stop and ask in these cases:
  - A ticket's scope turns out wrong.
  - Acceptance keeps failing.
  - A credential is missing: add the key to `.env` with an empty value and to `.env.example`,
    name the key, and stop.

## 6. Report

Report:
- the tracker used and the ticket links in order
- for developed tickets, what landed (PRs, branches or commits)
- what is still open
- anything that failed, with its output

Commit the plan doc only if the user asks or the pipeline commits it with the first ticket, on a
branch if the repo is on its default branch.
