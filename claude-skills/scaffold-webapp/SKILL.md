---
name: scaffold-webapp
description: Plan and build a web app on the default stack from the stack reference (FastAPI + pydantic back end, React + Vite + TanStack front end, OpenAPI codegen with a drift gate, just/mise/uv/pnpm, ruff/Oxlint/Oxfmt, pytest/Vitest/Playwright with axe), in a new or existing repo. Audits what the project already has and what it needs, agrees with the user per domain whether to skip, use raw files, use the industry-standard tool, keep what exists, or pick an alternative, reads versions from the reference, and writes docs/stack.md with the decisions. Drafts one ticket per unit of work and hands them to ticket-pipeline, which files them in the project's tracker once the user confirms and, if the user decides, develops them through the project's dev pipeline. Use when asked to scaffold, bootstrap, set up or start a web app, full-stack project or FastAPI + React app, or to add a stack domain (auth, jobs, persistence, real-time, forms, deployment) to an existing one. Triggers on "scaffold a webapp", "set up the web stack", "new full-stack project", "bootstrap the app", "add auth/jobs/db to this app".
---

# scaffold-webapp

Plans a project's web stack with the user, documents the decisions, and drafts the work as
tickets. The `ticket-pipeline` skill files them and, if the user decides to, develops them (step
6). Until then, the only file this skill writes in the project is `docs/stack.md`.

The stack reference, `~/.claude/skills/stack-decisions/stack-reference.md`, holds the tools,
tradeoffs, default picks, raw versions, agent notes and versions. Read the sections you need
(`rg -n '^#{2,3} '` lists them) and cite them by number in the docs and tickets. Don't restate
them here.

Observability is planned by a separate skill, `scaffold-observability`. Offer it at the end;
don't fold it in.

Run the steps in order. Each decision step ends with the user agreeing, through AskUserQuestion in
a few grouped questions, with your recommendation listed first.

## 1. Audit the project

**What exists.** Read the repo, don't guess:
- `docs/stack.md` from an earlier run. If present, it is the starting point, and this run extends it.
- Languages and managers: `pyproject.toml`, `uv.lock`, `requirements*.txt`, `package.json`, lockfiles,
  `mise.toml`, `.nvmrc`, `.python-version`.
- Frameworks and libraries in use, per domain of the domain map (reference 1).
- Tooling: linters, formatters, type checkers, test runners and their configs, `justfile` or
  `Makefile`, git hooks, CI workflows, Dockerfiles and Compose files.
- Agent instructions: `CLAUDE.md`, `AGENTS.md`, and whether a user harness (`.uh/`) is installed.
- Generated files and how they are produced.
- Shared services the project could use rather than run itself: Postgres, Valkey, object storage,
  an identity provider, an SMTP relay. Look in Compose files, config and `.env.example` (never
  `.env`), then ask the user what exists and who else uses it.

**The scope.** Profile the project against the reference profile (reference 0.2): who uses it,
public or internal, whether Python science code runs in the API, self-hosted or managed, expected
size, who maintains it. Take this from the request, the README and the code; ask only what is
still open.

Show the result as one table, one row per domain from reference 1 that the project touches or
plausibly needs: **domain · what exists · gap**. Leave out domains that clearly don't apply, and
say in one line which you left out.

## 2. Agree the scope

Each domain gets one tier:

| Tier | Meaning |
|---|---|
| **skip** | Not set up now |
| **raw** | The domain's raw version from the reference (section 4 and each domain's "Raw version"): plain files, CLIs, the smallest thing that works |
| **standard** | The reference's default pick for that domain, the industry-standard tool |
| **keep** | What the project already has stays; only wire it into the gates and docs |
| **connect** | Use a shared service found in the audit (a Postgres, Valkey, object store or IdP run elsewhere) instead of running one in this project |
| **alternative** | Another option from the domain's table or slot table, with the reason from its "Choose when" column |

Propose a tier for every row, with a recommendation based on the audit and the profile:
- Existing working choices default to **keep**.
- A small or early project leans **raw** for optional domains.
- The contract chain, types, lint, tests and `just check` are worth **standard** in almost every
  project.

For shared services, recommend what to share and what to keep separate: a separate database and
role inside a shared Postgres, a separate bucket and credentials in a shared object store, a
separate realm or client in a shared IdP, namespaced keys in a shared Valkey. Never replace a
working existing choice without the user agreeing to it explicitly.

## 3. Read versions

- Take the expected major version of each tool from the register (reference 6) and the domain's
  Notes. A fact marked `(verify)`, or dated three or more months back, gets checked against its
  primary source before it goes into a ticket. If the reference is out of date, update it per the
  `stack-decisions` skill.
- Tickets tell the developer to add dependencies with the package manager (`uv add`,
  `uv add --dev`, `pnpm add`) after the cooldowns are set (2.14, 2.17), and to pin tool versions
  in `mise.toml`. They don't list hand-edited version strings.

## 4. Write docs/stack.md

Write it in the project (or wherever it keeps docs) before any tickets exist, so the decisions
survive even if ticketing stops:

- The project profile in two lines, and the date.
- **Decision table:** domain · tier · tool · version · where it will live (paths) · reference
  section · ticket. The ticket column fills in when `ticket-pipeline` files them. Raw rows also
  say what the standard tier would be and what would trigger the move.
- **Shared and separate:** each shared service used, and what this project gets in it.
- Decisions that differ from the reference default, each with its reason.
- Commands: what each `just` recipe will do, and where run artifacts land (5.2).
- Generated files, how they are regenerated, and which gate checks them.
- Not set up: the domains skipped, in one list.

## 5. Draft the tickets

Draft one ticket per unit of work from the catalogue below, for the domains agreed in step 2 only,
in dependency order. Adapt each to the audit. In an existing repo, a ticket extends what is there:
it follows the repo's layout and naming, and replaces nothing the user didn't agree to replace.
Each ticket gets a title, context linking its `docs/stack.md` section, scope, acceptance and
dependencies, in the shape `ticket-pipeline` expects. Include the domain's "Agent notes" in its
scope; they hold the conventions the code and instructions must follow.

| # | Ticket | Scope | Acceptance |
|---|---|---|---|
| W1 | Toolchain | `mise.toml` pins, uv project with `exclude-newer`, pnpm workspace with `minimumReleaseAge` and `allowBuilds`, `justfile` with `setup`, `api`, `check`, `test` (2.14, 2.17) | `just setup` succeeds from a clean clone; `just --list` shows the recipes |
| W2 | Back-end skeleton | FastAPI app, pydantic-settings, one health route with `response_model` and a stable `operation_id`, a pytest `TestClient` test (2.9) | pytest passes; the route answers under uvicorn |
| W3 | Contract chain | Deterministic `scripts/export_openapi.py`, TS codegen, the drift gate, and oasdiff and Schemathesis at the agreed tiers (2.10) | `just api` twice leaves no diff; a model change without regenerating fails the gate |
| W4 | Front-end skeleton | Vite app with the agreed rendering, state, routing, styling and component picks, React Compiler on; one page calling the health route through the generated types (2.2 to 2.8, 2.19) | `vite build` passes; a Vitest test renders the page |
| W5 | Lint, format, types | ruff, pyright, Oxlint, Oxfmt, tsc, the small ESLint config for the TanStack Query plugin; generated files excluded (2.1, 2.11) | All pass; an introduced violation of each fails |
| W6 | Tests and accessibility | Vitest browser mode, Playwright journey with axe, JSON reporters (2.12, 2.13) | Suites pass and write machine-readable results |
| W7 | Gates and run artifacts | `just check` running the agreed gates cheapest first, `--fast`, `.artifacts/runs/<run_id>/`, `summary.json` with `first_failures`, `scripts/check` queries (2.15, 5.2 to 5.4) | A clean run passes every stage; an induced type error appears in `first_failures` with file and line |
| W8 | Hooks, CI, supply chain | lefthook for the fast gates, CI calling `just check`, osv-scanner, gitleaks, zizmor, Renovate, Actions pinned to SHAs, at the agreed tiers (2.15, 2.17) | A staged fake secret is blocked; CI passes on a PR |
| W9 | One ticket per optional domain | At its agreed tier, following the domain's section, with the gate or test its agent notes call for (table below) | The domain's check below passes |
| W10 | Agent instructions and docs | The parts of the 5.6 snippet that match what was built, in `CLAUDE.md` or `AGENTS.md`; mark items done in `docs/stack.md` | Instructions name only commands that exist and work |

Optional domains for W9:

| Domain | Section | Check |
|---|---|---|
| Persistence | 2.18 | `alembic check` in the gate; upgrade, downgrade, upgrade on a fresh test DB |
| Authentication and authorization | 2.20 | Gate test that fails on a route with neither an auth dependency nor the public marker; table-driven role × route tests |
| Background jobs | 2.21 | A job runs inline in tests and is enqueued in the same transaction as its data change |
| Real-time updates | 2.22 | An event invalidates the right query; streams have a max duration |
| Forms | 2.23 | Generated Zod in the drift gate; a 422 maps onto its field |
| Deployment | 2.24 | `docker compose up --wait` succeeds; `just smoke` passes against it |
| Caching | 2.25 | Tests run with `CACHE_ENABLED=false`; one invalidation test per cached path |
| Object storage | 2.26 | Presigned upload against the Compose S3 server in tests |
| Formatting and i18n | 2.27 | Table-driven `format.ts` tests under `TZ=UTC`; gate against formatting outside it |
| Config and feature flags | 2.28 | Tests set flags through an in-memory provider; stale-flag report in the summary |
| Visual review | 2.29 | `just visual` in the pinned Playwright container |
| Email | 2.30 | A test reads the sent message through Mailpit's API |

## 6. File and develop through ticket-pipeline

Hand the work to the `ticket-pipeline` skill with:

- **Plan doc:** `docs/stack.md`.
- **Draft tickets:** from step 5.
- **Presets:** "core set" (W1 to W7 and W10), "core plus hooks and CI" (adds W8).
- **Confirm-before:** any ticket that deploys beyond the local machine, applies IaC, sends real
  email, or connects to a shared service run elsewhere. Agents never deploy to production
  (2.24).

`ticket-pipeline` finds the tracker and the dev pipeline, confirms both with the user, files the
tickets after the user approves the list, and develops them if the user decides to.

## 7. Report

Give the user: the decision table, what is shared and what is kept separate, the link to
`docs/stack.md`, and `ticket-pipeline`'s report (ticket links, what landed, what is open). Then
offer `scaffold-observability`.
