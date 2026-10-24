---
name: scaffold-observability
description: Plan observability for a project with the user and file the work as tickets. Audits the code, servers, tests and LLM calls, and discovers shared or pre-existing telemetry services; agrees with the user the level of observability, which add-ons to include (LLM observability, evals, profiling, server metrics, test telemetry, front-end, error tracking, alerting), what to share across projects and what to keep separate, and raw files versus standard tools per item, with versions from the stack reference. Writes docs/observability.md with the decisions, then finds the project's ticketing pipeline and, once the user confirms, files one ticket per unit of work; if the user decides to go ahead, develops the tickets through the project's own dev pipeline, or directly when it has none. Use when asked to add or plan logging, tracing, metrics, telemetry, monitoring, LLM tracing, profiling or error tracking, or to set up or connect to an observability stack. Triggers on "set up observability", "add telemetry", "add tracing", "plan observability", "trace the LLM calls", "connect to SigNoz/Langfuse".
---

# scaffold-observability

Plans a project's observability with the user, documents the decisions, turns the work into
tickets in the project's own pipeline, and, if the user decides to, develops those tickets. Until
the user makes that decision (step 7), the only file it writes in the project is
`docs/observability.md`.

The stack reference, `~/.claude/skills/stack-decisions/stack-reference.md`, sections O1 to O8 and
2.16, holds the tools, tradeoffs, defaults, schemas and versions. Read the sections you need
(`rg -n '^#{2,3} '` lists them) and cite them by number in the docs and tickets. Don't restate
them here.

Run the steps in order. Each decision step ends with the user agreeing, through AskUserQuestion in
a few grouped questions, with your recommendation listed first.

## 1. Audit the project

Read the repo, don't guess, and record what you find:

- `docs/observability.md` from an earlier run. If present, it is the starting point.
- **Code:** languages, frameworks, entry points, and the key operations a trace should show inside
  business logic (jobs, external calls, expensive computations). Name them with file paths; they
  become manual-span work in the tickets.
- **Servers and processes:** what runs long-lived (API, workers, schedulers), where it runs
  (local, CI, one host, several), Compose or Kubernetes files, environments (dev, staging, prod).
- **Tests:** runners, how they're invoked, whether results are machine-readable, flaky or slow
  areas.
- **LLM calls:** provider SDKs or frameworks used, where they're called, whether prompts or
  outputs hold user data.
- **Front end:** whether there is a browser app and how it calls the API.
- **Telemetry already present:** loggers and their config, OTel packages, `OTEL_*` variables in
  config and `.env.example` (never read `.env`), Prometheus endpoints, vendor SDKs (Sentry,
  Datadog), a `.telemetry/` directory.
- **Data sensitivity:** secrets, tokens and personal data that could reach logs or traces.

## 2. Find shared and pre-existing services

Look before asking, then ask about what you couldn't find:

- `shared-services.local` next to this file: services recorded by earlier runs on this machine
  (endpoints, what each is for, which projects use it). It is gitignored; never put keys in it.
- The user harness telemetry config, `~/.config/user-harness/telemetry.env`, and its receiver
  (`telemetry-host/up.sh` in `~/projects/user-harness`: Grafana's all-in-one OTLP image).
- OTLP endpoints in the shell environment or in the project's config files.
- Running containers (`docker ps`) and Compose files in this repo or a sibling platform repo.
- Then ask the user: is there a SigNoz, Langfuse, Grafana stack, Sentry or GlitchTip, ClickHouse,
  Postgres or object store this project should use? Where does it run, and who else uses it?

Record anything new the user confirms in `shared-services.local`.

**Recommend what to share and what to keep separate**, then settle it with the user. Starting
points, which the user can override:

| Usually shared across projects | Usually kept per project |
|---|---|
| The observability backends: SigNoz (or another O4.3 platform), Langfuse, an error tracker, the Collector gateway in front of them | The local run directory and query scripts used in the agent loop |
| Object storage and ClickHouse operations, when one team runs them | API keys and credentials: one Langfuse project and one set of keys per project |
| Dashboards and alert routing conventions | `service.name`, `deployment.environment` and the Langfuse project, which keep data apart inside shared backends |
| | Product data such as chat transcripts, which belong in the app's own database (O1) |
| | Separate ClickHouse instances for SigNoz and Langfuse (O5.2), and separate dev and prod data when the data is sensitive |

Deploying a shared platform is never part of one project's Compose. If no platform exists and the
user wants one, it gets its own repo or host and its own ticket (T10).

## 3. Decide the level and the add-ons

Agree the **level** first:

| Level | What it covers | Fits when |
|---|---|---|
| **1. Agent loop** | Per-run JSONL telemetry, `summary.json`, bounded query scripts, locally and in CI (O3, O6) | Every project; enough until an O3.2 condition holds |
| **2. Shared environments** | Level 1, plus traces, logs and metrics from staging and production sent to a platform with a UI and retention (O4.3, O5.2) | Several machines or people, or production traffic |
| **3. Operated service** | Level 2, plus alerting, SLOs, on-call routing and retention policy (O2.5) | Someone gets paged when it breaks |

Then go through each **add-on**, and include it only if the user wants it:

- **LLM observability:** traces with tokens and cost, Langfuse sessions and prompt management (O2.4, O4.5).
- **Evals:** an eval set run like tests and diffed against a baseline (O6.7).
- **Code profiling:** a continuous profiler such as Pyroscope (O2.3, O5.2). Dev-time profilers aren't in the reference yet; add them through `stack-decisions` if chosen.
- **Server and infrastructure metrics:** host and container metrics, Prometheus scraping, eBPF for services that can't be instrumented (O2.1, O4.1).
- **Test telemetry:** test runs write into the run directory and summary; per-test spans; slow and flaky test tracking (O6.6).
- **Front-end telemetry:** browser OTel SDK with trace propagation to the API, and web-vitals (2.16).
- **Error tracking:** issue grouping beyond span exceptions (O2.6).
- **Alerting and dashboards:** at level 3, or earlier if wanted (O2.5).

For every included item, agree the **tier**:

| Tier | Meaning |
|---|---|
| **raw** | Files only: flat JSONL written by the app, queried with rg, jq, DuckDB (O3) |
| **standard** | The reference default (O5.2) |
| **connect** | Send to a shared service found in step 2 |
| **keep** | What the project already has stays, wired into the run directory and docs |
| **alternative** | Another option from the slot's table in O4, with the reason from its "Choose when" column |

Take versions from the register (O7) and the slot tables (O2). A fact marked `(verify)`, or dated
three or more months back, gets checked against its primary source before it goes into a
ticket; if the reference is out of date, update it per the `stack-decisions` skill.

## 4. Write docs/observability.md

Write it in the project (or wherever it keeps docs) before any tickets exist, so the decisions
survive even if ticketing stops:

- The project in two lines: what runs where, and the environments.
- **Level** chosen, and why.
- **Shared and separate:** each service used, where it runs, what this project gets in it
  (service name, environment names, Langfuse project), and what stays per project.
- **Decision table:** item · included or not · tier · tool · version · reference section · ticket.
  The ticket column fills in at step 6. Raw rows also say what the standard tier would be and
  which O3.2 condition would trigger the move.
- Signals captured, and where each lands in each environment.
- Redaction and retention rules.
- Items deliberately left out, with the reason.

If `docs/stack.md` exists, point its observability row at this file.

## 5. Find the ticketing pipeline

Look for it in this order and use the first that is clearly the project's own:

1. The project's `CLAUDE.md` or `AGENTS.md`, or the harness docs in `.uh/`, naming a board or tracker.
2. `BOARD_ORG` and `BOARD_PROJECT` in `.claude/settings.json`: a GitHub Projects board, written
   through the `gh-board` skill.
3. A GitHub remote with issues in use (`gh issue list --limit 5`) or a linked project
   (`gh project list`); a GitLab remote (`glab`).
4. Jira or Linear keys (`ABC-123`) in commit messages, branch names or PR templates.
5. A tracking file in the repo (`TODO.md`, `ROADMAP.md`, `docs/tasks/`).

Then confirm the pipeline with the user, even when it seems obvious. If none exists, offer GitHub
issues on the repo or a `docs/observability-tasks.md` checklist. Before writing, read the
pipeline's conventions (issue templates, labels, board fields and statuses, how dependencies are
linked) and follow them.

## 6. Draft, confirm, file

Draft one ticket per unit of work from the catalogue below, for the items agreed in step 3 only,
in dependency order. Every ticket has:

- **Title** in the tracker's style.
- **Context:** one paragraph, and a link to the relevant `docs/observability.md` section.
- **Scope:** what to build, with file paths from the audit, tools, versions, reference sections.
- **Acceptance:** commands that prove it works, and their expected output.
- **Depends on:** the tickets that must land first.

Show the user the complete list (titles, dependencies, one-line scope each) and ask for changes.
File nothing until they confirm. Then create the tickets, link the dependencies the way the
tracker does, write each ticket's link into the decision table in `docs/observability.md`, and
report the links.

### Ticket catalogue

Take the tickets that apply, adapt each to the audit, split any that are too big for one PR.

| # | Ticket | Scope | Acceptance |
|---|---|---|---|
| T1 | Run plumbing | Create `.telemetry/runs/<run_id>/`, the `latest` link, gitignore, keep last N. `run_id` comes from `TELEMETRY_RUN_ID` when the caller (`just`, test runner, CI) sets it, else generated. Reuse the `.artifacts` run ID when the web stack has one (2.16) | Two runs produce two directories; `latest` points at the newer one |
| T2 | Telemetry module | One small module per language (for example `telemetry.py`, `telemetry.ts`) that starts a run, sets up the OTel tracer provider with an exporter writing flat JSONL spans (O6.2 schema, not OTLP JSON), attaches a log handler adding `trace_id` and `span_id`, fingerprints errors, redacts at write time, and offloads long payloads to `payloads/`. It wraps the existing logger rather than adding a second one | Unit tests for schema, fingerprint and redaction; a secret in a log call never reaches disk |
| T3 | Server instrumentation | Auto-instrumentation for the frameworks found (for example FastAPI, httpx, the DB driver), plus manual spans around the key operations listed in the audit, with a short how-to for adding more | Hitting one route gives a trace with route, outgoing-call and DB spans in `spans.jsonl` |
| T4 | Front-end telemetry | Browser OTel SDK, fetch instrumentation passing `traceparent` to the API, web-vitals | One page load gives one trace covering browser and API spans |
| T5 | Test telemetry | pytest plugin or conftest hook and Vitest setup file that set `run_id` per session and record results for the summary; optional per-test spans | A test run writes its results into the run directory |
| T6 | Summary and query scripts | `scripts/telemetry summary` builds `summary.json` from the run files (so it works for long-running servers and tests alike), plus `errors`, `trace`, `llm`, `diff`, all with bounded output (O6.3) | An induced error shows up in `errors` with a fingerprint and count; `trace <id>` prints the span tree |
| T7 | LLM observability | Instrumentation or a wrapper for each LLM call site found, writing `llm.jsonl` (tokens, cost, latency, previews, payload refs); Langfuse SDK when tier is standard or connect; record the GenAI semantic-convention version (O6.8) | One model call appears in `llm.jsonl`, and in Langfuse if connected |
| T8 | Evals | Eval set as JSONL, a runner that scores each case and adds an `evals` line to the summary, `diff` against a baseline (O6.7) | Evals run from `just` and the summary shows pass counts |
| T9 | Connect to shared services | Collector or exporter config pointing at the shared endpoint, `service.name` and `deployment.environment` set, keys added to `.env` with empty values and to `.env.example` | A test span and log arrive in the shared backend under the project's service name |
| T10 | Platform deployment | Only when no shared platform exists and the user wants one, in its own repo or host: Collector, SigNoz, Langfuse and their stores (O5.2), healthchecks, pinned image tags, private network only | `docker compose up --wait` succeeds; a test span arrives |
| T11 | Error tracking | Sentry-compatible SDK pointed at GlitchTip or Sentry (O2.6), with source maps for the front end | An induced exception creates one grouped issue |
| T12 | Code profiling | Continuous profiler agent sending to the agreed backend (O2.3) | A flame graph for the API appears under its service name |
| T13 | Server and infra metrics | Host and container metrics, Prometheus scrape config, eBPF for services that can't be instrumented (O2.1, O4.1) | CPU, memory and request-rate metrics visible per service |
| T14 | Alerting and dashboards | Error-rate and latency alerts routed to the agreed channel, one service dashboard, SLOs at level 3 (O2.5) | A test alert reaches the channel |
| T15 | Agent instructions and docs | Add the O6.4 telemetry snippet, trimmed to what was built, to `CLAUDE.md` or `AGENTS.md`; mark items done in `docs/observability.md` | Instructions name only commands that exist and work |

## 7. Develop the tickets, if the user decides to

Ask the user whether to develop the tickets now, and which: all, the level-1 set (T1, T2, T3, T5,
T6, T15), or a chosen list. In the same question, settle how the work lands: the pipeline's own
way, or, without a pipeline, commits on a branch, a PR, or uncommitted changes for review. Stop
here if they say no.

**Find the dev pipeline**, the way work normally moves from ticket to merged code:

- **User harness** (`.uh/` and `docs/agents/orchestration.md`): follow it exactly. That means a
  worktree and branch per feature, `testwriter` then `coder`, a `Paths:` line and a `Ticket: #N`
  line in every subagent prompt, `scripts/verify`, friction entries, and a PR per ticket. The
  main session orchestrates and does not edit `src/` or `tests/` itself.
- **Instructions or project skills:** a workflow in `CLAUDE.md` or `AGENTS.md`, or a ticket
  command or skill in `.claude/`. Use it as written.
- **Board and PR conventions:** move each ticket through the board's statuses as work starts and
  lands (`gh-board`), and link each PR so merging closes its ticket (`gh-pr-linking`). Let CI run
  on each PR.

Name the pipeline you found, and how you'll drive it, to the user before starting.

**If there is no pipeline,** develop the tickets directly. Branch first if on the default branch,
implement one ticket at a time, run its acceptance commands and the project's own checks, show
their output, and land it the way the user chose.

**Either way:**

- Work in dependency order. Run independent tickets in parallel only where the pipeline allows it
  (separate worktrees, no overlapping paths).
- A ticket is done when its acceptance commands pass, with output shown. Never mark it done
  because the code looks right.
- After each ticket lands, update its row in `docs/observability.md` and its status in the
  tracker.
- Stop and ask before T10 (deploying a platform) or T9 (first data sent to a shared service),
  since both act outside the repo. Also stop and ask when a ticket's scope turns out wrong, when
  acceptance keeps failing, or when a credential is missing. For a missing credential, add the
  key to `.env` with an empty value and to `.env.example`, say which key, and stop.

## 8. Report

Give the user: the level and add-ons chosen, what is shared and what is kept separate, the link to
`docs/observability.md`, the ticket links in order, and, for developed tickets, what landed
(PRs, branches or commits) and what is still open. Commit `docs/observability.md` only if the
user asks or the pipeline commits it with the first ticket, on a branch if the repo is on its
default branch.
