---
name: scaffold-observability
description: Plan observability for a project with the user and file the work as tickets. Audits the code, servers, tests and LLM calls, and discovers shared or pre-existing telemetry services; agrees with the user the level of observability, which add-ons to include (LLM observability, evals, profiling, server metrics, test telemetry, front-end, error tracking, alerting), what to share across projects and what to keep separate, and raw files versus standard tools per item, with versions from the stack reference. Writes docs/observability.md with the decisions, drafts one ticket per unit of work, and hands them to ticket-pipeline, which files them in the project's tracker once the user confirms and, if the user decides, develops them through the project's dev pipeline. Use when asked to add or plan logging, tracing, metrics, telemetry, monitoring, LLM tracing, profiling or error tracking, or to set up or connect to an observability stack. Triggers on "set up observability", "add telemetry", "add tracing", "plan observability", "trace the LLM calls", "connect to SigNoz/Langfuse".
---

# scaffold-observability

Plans a project's observability with the user, documents the decisions, and drafts the work as
tickets. The on-demand `ticket-pipeline` skill (`~/.skills/ticket-pipeline/SKILL.md`) files them and, if the user decides to, develops them (step
6). Until then, the only file this skill writes in the project is `docs/observability.md`.

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
- **User harness:** a `.uh/` directory means the repo runs the user harness, which already writes
  into `.telemetry/runs/` (see "User harness" below). Its lines are an existing producer to keep
  and ship, never to replace.
- **Data sensitivity:** secrets, tokens and personal data that could reach logs or traces.

## 2. Find shared and pre-existing services

Look before asking, then ask about what you couldn't find:

- `shared-services.local` next to this file: services recorded by earlier runs on this machine
  (endpoints, what each is for, which projects use it). It is gitignored; never put keys in it.
- OTLP endpoints in the shell environment or in the project's config files, including Claude
  Code's own OpenTelemetry variables (`CLAUDE_CODE_ENABLE_TELEMETRY`, `OTEL_*`) in the shell profile.
  A leftover `~/.config/user-harness/telemetry.env` comes from the retired `uh telemetry setup`;
  T16 replaces it.
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

### User harness

When the repo has `.uh/`, this skill's observability system takes precedence over the harness's
telemetry and incorporates it. The harness only produces events; everything else is owned here. The
same table is in the harness README ("Telemetry boundary"); keep the two in step.

| Concern | Owner |
|---|---|
| Harness events (what, when, fields) | user harness |
| Run directory layout, `latest`, summary, query scripts | observability (this skill) |
| Retention and rotation | observability |
| Shipping to a backend, endpoints, credentials | observability |
| Claude Code's own OTel settings | observability (T16) |
| Test results file (JUnit) | the test runner; the harness's `junit_xml` slot points at it |

What the harness writes: O6.2 log lines in `.telemetry/runs/<run>/logs.jsonl` of the main checkout
(worktrees included), with `service: "user-harness"`, the event name in `msg`, and `uh.schema`
versioning the fields. Each `scripts/verify` is a run: it honours `TELEMETRY_RUN_ID`, creates the run
otherwise, exports `TELEMETRY_RUN_ID` to the test commands it runs, and points `latest` at the run.
Each Claude session has a `<ts>_session-<id>` run that never moves `latest`. The harness ships
nothing and deletes nothing; long-term harness history lives in the shared backend once one exists.

Tickets in a harnessed repo follow this (step 5 adapts them):

- **T1:** the layout may already exist, created by the harness; reuse it. Session runs never take
  `latest`. Rotation applies to harness runs too.
- **T5:** produce the JUnit file and point `.uh/verify.toml`'s `[tests] junit_xml` at it, so verify
  reads the same results; set the run from `TELEMETRY_RUN_ID` when present.
- **T6:** the summary and query scripts read `service: user-harness` lines like any other service;
  `summary` of a session run is valid but never the default.
- **T9:** ship the harness's lines with the rest, under `service.name=user-harness`.
- **T15:** the agent instructions go in `AGENTS.md`, never `CLAUDE.md` (which must stay `@AGENTS.md`),
  each rule a bullet with an `HL-nnn` id and a row in `.uh/harness-log.md`, in its own harness-only
  PR; `scripts/verify` checks this.

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
- **Claude Code telemetry:** Claude Code's own metrics and events from this machine, sent to the
  agreed collector (T16). Per machine, so skip it if an earlier run already set it up here. If it
  is included, agree the content capture below.

### Claude Code content capture

By default Claude Code's telemetry carries metrics and event metadata, with no conversation content.
Content is opt-in, one variable per kind, and each sits on top of `CLAUDE_CODE_ENABLE_TELEMETRY=1`
(source: https://code.claude.com/docs/en/monitoring-usage, read 2026-10-24; re-check it before
writing T16):

| Variable | Adds |
|---|---|
| `OTEL_LOG_USER_PROMPTS=1` | Prompt text on `user_prompt` events |
| `OTEL_LOG_ASSISTANT_RESPONSES=1` | Response text on `assistant_response` events; when unset it follows `OTEL_LOG_USER_PROMPTS` |
| `OTEL_LOG_TOOL_DETAILS=1` | Tool inputs (Bash commands, file paths, MCP, skill and agent names) |
| `OTEL_LOG_TOOL_CONTENT=1` | Tool output (file text read, command output) on `tool.output` span events; needs tracing (`CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` and `OTEL_TRACES_EXPORTER`) |
| `OTEL_LOG_RAW_API_BODIES=1` or `file:<dir>` | Every API request and response body, which holds the whole conversation (system prompt, turns, tool results; extended thinking is always redacted). This is the closest to a full transcript. `1` puts the bodies inline, truncated at `CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH` (60 KB default); `file:<dir>` writes them whole to disk with a `body_ref` in the event |

Subagents use the same switches. Their events carry `agent_id` and `parent_agent_id` (absent on the
main session; Claude Code v2.1.310 or later), and `query_source` names the subagent. Their trace
spans nest under the parent's `Agent` tool span, and `subagent_completed` sums each run. Three gaps:
- the docs don't say whether the raw body events carry `agent_id`;
- the task prompt a subagent receives is not a `user_prompt` event, so it is only in the parent's tool details or the raw bodies;
- custom agent names show as `"custom"` unless `OTEL_LOG_TOOL_DETAILS` is on.

Claude Code ignores these variables in a repo's `.claude/settings.json` and
`.claude/settings.local.json`, so content capture is a per-machine choice made in T16 and never
a harness or repo setting. Without any of it, full transcripts, subagents' included, already sit on
this machine at `~/.claude/projects/<project>/<session-id>.jsonl` and
`<session-id>/subagents/agent-<id>.jsonl`.

Ask which level to capture, with "off" first and recommended:

| Level | Variables set to `1` |
|---|---|
| **off** (default) | none |
| **prompts and responses** | `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_ASSISTANT_RESPONSES` |
| **plus tools** | the above, plus `OTEL_LOG_TOOL_DETAILS` and, if tracing is on, `OTEL_LOG_TOOL_CONTENT` |
| **full transcripts** | the above, plus `OTEL_LOG_RAW_API_BODIES` |

Content holds secrets, `.env` values that a tool read, and file contents. Offer anything above
"off" only when the collector and backend are on this machine or private to the user, never a
backend other people can read. Record the level and its reason under "Redaction and retention" in
`docs/observability.md`.

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

## 5. Draft the tickets

Draft one ticket per unit of work from the catalogue below, for the items agreed in step 3 only,
in dependency order. Adapt each to the audit: file paths, the frameworks found, the key operations
named. Each ticket gets a title, context linking its `docs/observability.md` section, scope,
acceptance and dependencies, in the shape `ticket-pipeline` expects.

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
| T15 | Agent instructions and docs | Add the O6.4 telemetry snippet, trimmed to what was built, to `CLAUDE.md` or `AGENTS.md` (in a harnessed repo: `AGENTS.md` only, per "User harness"); mark items done in `docs/observability.md` | Instructions name only commands that exist and work; in a harnessed repo `scripts/verify` passes |
| T16 | Claude Code telemetry | Per machine, not per repo: an env file sourced from the shell profile setting `CLAUDE_CODE_ENABLE_TELEMETRY=1`, the OTLP exporters and the endpoint of the agreed collector, and the content variables for the agreed capture level (all off by default; see "Claude Code content capture"); replaces a leftover `~/.config/user-harness/telemetry.env` | A Claude Code session's metrics arrive in the backend under its service name; content appears only at the agreed level (a prompt's text shows on `user_prompt` exactly when the level includes prompts) |

## 6. File and develop through ticket-pipeline

Read `~/.skills/ticket-pipeline/SKILL.md` and follow it, with these inputs:

- **Plan doc:** `docs/observability.md`.
- **Draft tickets:** from step 5.
- **Presets:** "level-1 set" (T1, T2, T3, T5, T6, T15).
- **Confirm-before:** T9, since it sends data to a shared service for the first time, T10,
  since it deploys outside the repo, and T16, since it changes this machine's shell profile and
  sends Claude Code's telemetry out (and, above "off", conversation content).

`ticket-pipeline` finds the tracker and the dev pipeline, confirms both with the user, files the
tickets after the user approves the list, and develops them if the user decides to.

## 7. Report

Give the user: the level and add-ons chosen, what is shared and what is kept separate, the link to
`docs/observability.md`, and `ticket-pipeline`'s report (ticket links, what landed, what is open).
