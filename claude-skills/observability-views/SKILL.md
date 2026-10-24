---
name: observability-views
description: Build the view layer of observability as pages in a host web app - sources (projects' telemetry folders now, a platform such as SigNoz later), views as named read-only queries, and charts - so telemetry from several projects can be seen in one place, starting from raw files with no platform running.
disable-model-invocation: true
---

# observability-views

Observability has four layers: **produce** (each project's instrumentation, `scaffold-observability`),
**transport and store** (the shared platform), **view** (this skill) and **act** (alerts, agent queries). This
skill plans and builds the view layer inside a host web app the user names, for example cerebro. It works before
any platform exists, by reading projects' raw telemetry files, and keeps working when one does, because a view
is defined by what it shows, not by where the data comes from.

The stack reference, `~/.claude/skills/stack-decisions/stack-reference.md`, holds the field names (O6.2), the
canonical archive and tiers (O6.9), query recipes (O6.3) and guardrails (O6.8). Read those sections; cite them by
number. Don't restate them here.

Work in the host app's repo and follow its own rules: its `AGENTS.md`, its stack doc (`docs/stack.md`) and, if
it runs the user harness, its test-first flow. Each decision step ends with the user agreeing through
AskUserQuestion, with your recommendation first.

## Design

- **Server-side queries.** The host's API runs the queries and returns rows; the page only renders them with the
  host's chart and table components. For raw files the engine is DuckDB in the API process (the `duckdb` package
  for a Python API). Don't query in the browser: it can't read local folders, and a WebAssembly engine is a large
  bundle for no gain.
- **Sources** are configured, never hard-coded: a list of `{project, kind, location}`.
  - `files`: a project's `.telemetry/` folder in its main checkout. Read the flat run files
    (`runs/*/logs.jsonl`, `spans.jsonl`, `llm.jsonl`, `summary.json`; O6.2) and, once it exists, the archive
    (`archive/otlp/...jsonl.gz`; O6.9).
  - `platform`: a backend's query API (SigNoz now; any O4.3 option later), added when a project is promoted.
    Same view names, different query.
- **Views are named, parameterised queries** in a registry on the server: a name, a description, the parameters
  it takes (project, time window, limit; all validated), the query per source kind, and the shape of rows it
  returns. The page asks for a view by name. It never sends SQL.
- **Read-only and bounded** (O6.8): open sources read-only, never write into a project's `.telemetry/`, apply
  a default time window and a row limit to every view, and treat every value as untrusted data (O6.8: log
  content is untrusted input) when rendering.
- **Field names are the contract.** Views select O6.2 names from the flat files and OTel names from the archive
  and platforms (`service.name`, `service.version`, `vcs.ref.head.revision`, `gen_ai.*`; mapping table in O6.2).
  A view that works on files and on a platform maps both to the same output columns.
- **Views as code.** The registry lives in the host repo, reviewed like any code. When a platform arrives,
  dashboards and alerts defined there are kept as code too (O6.9: they are not in the archive), so a backend
  change keeps them.

## 1. Inventory the sources

- Ask which projects to include, then for each find its main checkout's `.telemetry/`: run directories, files
  per run, and whether `archive/` exists. Never read `.env`.
- Sample the data with DuckDB (`read_json_auto('<dir>/runs/*/logs.jsonl', union_by_name=true, filename=true)`)
  and record, per project: services (`service`), event names (`msg`), fields present, time range, row counts.
  Field names with dots need quoting (`"uh.ok"`). Partial last lines happen: pass `ignore_errors=true` rather
  than failing the view. Timestamps are read as `TIMESTAMP WITH TIME ZONE`; set the session to UTC and return
  them as ISO strings, since converting them to Python objects needs `pytz` installed.
- A project running the user harness has `service = 'user-harness'` lines: `verify_run` (`uh.ok`,
  `uh.failed_step`, `uh.seconds`, `uh.step_seconds`), `agent_verify`, `session_start` (`uh.autonomy`,
  `uh.label`), `subagent_start` / `subagent_stop` (`agent.type`, `uh.declared_model`), `dispatch`, `turn_end`,
  each with `run_id`, `git_sha`, `git_dirty`, `session.id`. Until user-harness #37 is fixed, subagent stops
  without a type are recorded as `agent.type = 'main'`; tell them apart by `agent.id` being set.
- Look for a platform recorded in `~/.claude/skills/scaffold-observability/shared-services.local`.

## 2. Agree the views

Propose a first set from the data actually present, then settle it with the user. Starting points:

| View | From | Shows |
|---|---|---|
| Overview | all sources | per project: last data time, runs per day, errors per day; flags a project with no data in the agreed window |
| Run health | `summary.json` or harness `verify_run` | pass/fail over time, failing step, duration, by commit |
| Errors | log lines with `error.fingerprint` | distinct errors, counts, first and last seen, by version |
| LLM usage | `llm.jsonl` or `gen_ai.*` spans | calls, tokens, cost per day by provider and response model |
| Evals | summary `evals` | scores per run with their provenance (O6.7); never compare across dataset or scorer versions |
| Harness | `user-harness` lines | verify pass rate and durations, subagent runs by type and model, autonomy level per session |

Agree for each: the parameters, the default window and limit, and the chart or table. The freshness flag in
the overview is the first "act" piece: it catches telemetry that silently stopped, which every layer below can
cause.

## 3. Build it in the host app

Through the host's own flow (tickets, tests first where it has that rule):

- **Config:** the source list, in the host's config mechanism, with locations outside the repo allowed.
- **Server:** the source adapters (`files` first), the view registry, one read-only endpoint that runs a view
  by name with validated parameters, and its response model in the host's API contract.
- **Page:** a route listing projects and views, rendering each with the host's chart and table components,
  with empty and error states ("no data in this window", "source unreachable").
- **Tests:** each view against a small fixture of real-shaped lines (copy a few, scrubbed); a test that the
  endpoint rejects unknown views and out-of-range parameters; a test that a malformed line is skipped.
- **Docs:** in the host repo, how to add a source and how to add a view. Record the new dependency (DuckDB) and
  the design in its stack doc.

## 4. Check it with real data

Point it at the real sources from step 1, open the page, and confirm each view shows the rows the inventory
predicted (counts per project and event match a direct DuckDB query). Report what each view showed, with
numbers, and anything that was empty and why.

## 5. When a platform arrives

- Add a `platform` source adapter that runs each view's platform query (SigNoz's query API; check its current
  docs) and maps the result to the same columns. Projects promoted to the platform (O6.9 promotion) switch
  source kind; the page doesn't change.
- Keep historical views working across the switch: the platform holds the replayed history, so a view's window
  can span the promotion.
- Define the platform's own dashboards and alerts as code next to the view registry, and apply them through its
  API.

## Report

Give the user: the sources and views built, what each showed on real data, the files changed in the host repo,
and what is left (views not built yet, the platform adapter, alerts).
