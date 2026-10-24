---
name: scaffold-webapp
description: Scaffold or extend a web app on the default stack from the stack reference (FastAPI + pydantic back end, React + Vite + TanStack front end, OpenAPI codegen with a drift gate, just/mise/uv/pnpm, ruff/Oxlint/Oxfmt, pytest/Vitest/Playwright with axe), in a new or existing repo. Audits what the project already has and what it needs, agrees with the user per domain whether to use raw files or the industry-standard tool, reads versions from the reference, and leaves docs/stack.md describing what was set up. Use when asked to scaffold, bootstrap, set up or start a web app, full-stack project, FastAPI + React app, or to add a stack domain (auth, jobs, persistence, real-time, forms, deployment) to an existing one. Triggers on "scaffold a webapp", "set up the web stack", "new full-stack project", "bootstrap the app", "add auth/jobs/db to this app".
---

# scaffold-webapp

Builds the web stack described in the stack reference,
`~/.claude/skills/stack-decisions/stack-reference.md`, into a project. The reference is the only
place stack facts live: tools, tradeoffs, default picks, raw versions, agent notes and versions.
Don't restate them here or in the project; read the sections you need (`rg -n '^#{2,3} '` lists
them) and cite them by number in the docs you leave.

Observability is a separate skill, `scaffold-observability`. Offer it at the end; don't fold it in.

## 1. Audit the project

Before proposing anything, find out what exists and what the project is.

**What exists.** Read the repo, don't guess:
- `docs/stack.md` from an earlier run: if present, it is the starting point, and this run extends it.
- Languages and managers: `pyproject.toml`, `uv.lock`, `requirements*.txt`, `package.json`, lockfiles,
  `mise.toml`, `.nvmrc`, `.python-version`.
- Frameworks and libraries in use, per domain of the domain map (reference 1).
- Tooling: linters, formatters, type checkers, test runners and their configs, `justfile` or
  `Makefile`, git hooks, CI workflows, Dockerfiles and Compose files.
- Agent instructions: `CLAUDE.md`, `AGENTS.md`, and whether a user harness (`.uh/`) is installed.
- Generated files and how they are produced.

**The scope.** Profile the project against the reference profile (reference 0.2): who uses it,
public or internal, whether Python science code runs in the API, self-hosted or managed, expected
size, who maintains it. Take this from the request, the README and the code; ask only what is
still open.

Show the result as one table, one row per domain from reference 1 that the project touches or
plausibly needs: **domain · what exists · gap**. Leave out domains that clearly don't apply, and
say in one line which you left out.

## 2. Agree the scope with the user

Each domain gets one tier:

| Tier | Meaning |
|---|---|
| **skip** | Not set up now |
| **raw** | The domain's raw version from the reference (section 4 and each domain's "Raw version"): plain files, CLIs, the smallest thing that works |
| **standard** | The reference's default pick for that domain, the industry-standard tool |
| **keep** | What the project already has stays; only wire it into the gates and docs |
| **alternative** | Another option from the domain's table or slot table, with the reason from its "Choose when" column |

Propose a tier for every row, with a recommendation based on the audit and the profile: existing
working choices default to **keep**; a small or early project leans **raw** for optional domains;
the contract chain, types, lint, tests and `just check` are worth **standard** in almost every
project. Then settle it with the user using AskUserQuestion, grouping domains so it takes a few
questions, not thirty. Never replace a working existing choice without the user agreeing to it
explicitly.

Write the agreed table into `docs/stack.md` (section 5 below) before scaffolding, so an
interrupted run still leaves the plan behind.

## 3. Read versions

- Take the expected major version of each tool from the register (reference 6) and the domain's
  Notes.
- Add dependencies with the package manager (`uv add`, `uv add --dev`, `pnpm add`), not by
  editing manifests. Set the cooldowns first (reference 2.14, 2.17: uv `exclude-newer`, pnpm
  `minimumReleaseAge`) so resolution respects them.
- Pin tool versions (node, python, uv, pnpm, just, lefthook) in `mise.toml`.
- If a resolved major differs from the reference, or the reference marks the fact `(verify)` or
  dates it three or more months back, check the primary source. If the reference is out of date,
  update it per the `stack-decisions` skill and continue with the verified version.

## 4. Scaffold

Work in this order, and run the relevant check after each step rather than at the end:

1. **Toolchain:** `mise.toml`, uv project, pnpm workspace, `justfile` with `setup`, `api`,
   `check`, `test` recipes (reference 2.14).
2. **Back end:** FastAPI app, settings via pydantic-settings, `response_model` and stable
   `operation_id` on every route (2.9). One health route.
3. **Contract chain:** `scripts/export_openapi.py`, TS codegen, the drift gate, oasdiff and
   Schemathesis at the agreed tiers (2.10).
4. **Front end:** Vite app with the agreed rendering, state, routing, styling and component
   picks (2.2 to 2.8, 2.19). One page that calls the health route through the generated types.
5. **Lint, format, types:** ruff, pyright, Oxlint, Oxfmt, tsc, with generated files excluded
   (2.1, 2.11).
6. **Tests:** one pytest, one Vitest and, if agreed, one Playwright journey with axe (2.12, 2.13).
7. **Gates and run artifacts:** `just check` running the agreed gates cheapest first, writing
   `.artifacts/runs/<run_id>/` and `summary.json`, gitignored, last N kept (2.15, 5.2, 5.3).
   Add `scripts/check` query commands at the agreed tier (5.4).
8. **Hooks, CI, supply chain:** lefthook for fast gates; CI calling `just check`; osv-scanner,
   gitleaks and the rest at the agreed tiers (2.15, 2.17).
9. **Optional domains** at their agreed tiers, each with one test proving it works: persistence,
   auth, jobs, real-time, forms, caching, storage, i18n, flags, visual review, email, deployment
   (2.18 to 2.30).

In an existing repo, extend what is there: follow its layout and naming, and never overwrite a
file without showing the user what would change. Read each domain's "Agent notes" before writing
it; they hold the conventions the docs and instructions file must state.

## 5. Leave documentation behind

**`docs/stack.md`** in the project (or where the project keeps docs). Write the plan into it in
step 2 and finish it here:

- One line on the project profile and when this was set up.
- The domain table: **domain · tier · tool · version · where it lives (paths) · reference section**.
  Rows marked raw also say what the standard tier would be and what would trigger the move.
- Decisions that differ from the reference default, each with its reason.
- Commands: what each `just` recipe does, and where run artifacts land.
- Generated files, how they are regenerated, and which gate checks them.
- Not set up: the domains skipped, in one list.

**Agent instructions:** add the parts of the reference's snippet (5.6) that match what was set up
to the project's `CLAUDE.md` or `AGENTS.md` (whichever exists; create `CLAUDE.md` if neither
does, or follow the harness if `.uh/` is present). Write only rules for things that exist in the
repo, and point to `docs/stack.md` for the rest.

## 6. Verify and report

Run `just setup` and `just check` from clean, and show the summary output. If something fails,
fix it or report it as failing; don't call the scaffold done until the gates pass or the user
accepts the failures.

Report: the domain table as set up, the commands to run, what was deferred. Commit only if the
user asks; branch first if on the default branch. Then offer `scaffold-observability`.
