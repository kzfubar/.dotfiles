#!/usr/bin/env node
/**
 * board — a CLI for reading and writing a GitHub Projects v2 board and its issues.
 *
 * Tickets on the board ARE GitHub issues. "Editing a ticket" edits the issue;
 * "adding a comment" comments on the issue; board-specific fields (Status, Class,
 * Lab Priority, ...) are set on the project item.
 *
 * Auth + transport is entirely delegated to the `gh` CLI (must be installed and
 * authenticated with `project`, `repo`, and `read:org` scopes). No tokens live here.
 *
 * Runs directly on Node >= 23.6 (native TypeScript type-stripping). No build step.
 */

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

type Config = { org: string; projectNumber: number };

function loadConfig(): Config {
  const cfg = JSON.parse(
    readFileSync(join(HERE, "board.config.json"), "utf8"),
  ) as Config;
  return {
    org: process.env.BOARD_ORG ?? cfg.org,
    projectNumber: Number(process.env.BOARD_PROJECT ?? cfg.projectNumber),
  };
}

// ---------------------------------------------------------------------------
// gh helpers
// ---------------------------------------------------------------------------

function gh(args: string[], input?: string): string {
  try {
    return execFileSync("gh", args, {
      encoding: "utf8",
      input,
      maxBuffer: 64 * 1024 * 1024,
    }).trim();
  } catch (err: any) {
    const stderr = err?.stderr?.toString?.() ?? "";
    const stdout = err?.stdout?.toString?.() ?? "";
    fail(`gh ${args.join(" ")}\n${stderr || stdout || err?.message || err}`);
  }
}

function graphql(query: string, vars: Record<string, string> = {}): any {
  const args = ["api", "graphql", "-f", `query=${query}`];
  for (const [k, v] of Object.entries(vars)) args.push("-f", `${k}=${v}`);
  return JSON.parse(gh(args));
}

// ---------------------------------------------------------------------------
// Project schema (cached per invocation)
// ---------------------------------------------------------------------------

type FieldOption = { id: string; name: string };
type Field = {
  id: string;
  name: string;
  dataType: string;
  options?: FieldOption[];
};
type Project = { id: string; title: string; fields: Field[] };

let _project: Project | null = null;

function getProject(cfg: Config): Project {
  if (_project) return _project;
  // org comes from config (trusted) and num is a number, so inline them — this
  // avoids gh's `-f` sending the Int! arg as a string.
  const data = graphql(`
    query {
      organization(login: ${JSON.stringify(cfg.org)}) {
        projectV2(number: ${cfg.projectNumber}) {
          id
          title
          fields(first: 50) {
            nodes {
              ... on ProjectV2FieldCommon { id name dataType }
              ... on ProjectV2SingleSelectField { id name options { id name } }
            }
          }
        }
      }
    }`);
  const p = data?.data?.organization?.projectV2;
  if (!p) fail(`Could not load project #${cfg.projectNumber} for org ${cfg.org}`);
  _project = { id: p.id, title: p.title, fields: p.fields.nodes };
  return _project;
}

function findField(cfg: Config, name: string): Field {
  const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
  const target = norm(name);
  const fields = getProject(cfg).fields;
  const match =
    fields.find((f) => norm(f.name) === target) ??
    fields.find((f) => norm(f.name).includes(target));
  if (!match)
    fail(
      `Unknown field "${name}". Available: ${fields.map((f) => f.name).join(", ")}`,
    );
  return match;
}

/** Match a single-select option by name, ignoring emoji/case/punctuation. */
function findOption(field: Field, value: string): FieldOption {
  if (!field.options) fail(`Field "${field.name}" is not a single-select field.`);
  const norm = (s: string) =>
    s.toLowerCase().replace(/[^a-z0-9]/g, "");
  const target = norm(value);
  const opts = field.options!;
  const match =
    opts.find((o) => norm(o.name) === target) ??
    opts.find((o) => norm(o.name).includes(target)) ??
    opts.find((o) => target && norm(o.name).startsWith(target));
  if (!match)
    fail(
      `Unknown value "${value}" for field "${field.name}". Options: ${opts
        .map((o) => o.name)
        .join(", ")}`,
    );
  return match;
}

// ---------------------------------------------------------------------------
// Reference parsing  (URL | owner/repo#N | repo#N)
// ---------------------------------------------------------------------------

type IssueRef = { owner: string; repo: string; number: number; url: string };

function parseRef(cfg: Config, ref: string): IssueRef {
  let m =
    ref.match(
      /github\.com\/([^/]+)\/([^/]+)\/issues\/(\d+)/,
    ) ?? null;
  if (m)
    return {
      owner: m[1],
      repo: m[2],
      number: Number(m[3]),
      url: `https://github.com/${m[1]}/${m[2]}/issues/${m[3]}`,
    };
  m = ref.match(/^([^/]+)\/([^/#]+)#(\d+)$/);
  if (m)
    return {
      owner: m[1],
      repo: m[2],
      number: Number(m[3]),
      url: `https://github.com/${m[1]}/${m[2]}/issues/${m[3]}`,
    };
  m = ref.match(/^([^/#]+)#(\d+)$/);
  if (m)
    return {
      owner: cfg.org,
      repo: m[1],
      number: Number(m[2]),
      url: `https://github.com/${cfg.org}/${m[1]}/issues/${m[2]}`,
    };
  fail(
    `Could not parse ticket reference "${ref}". Use a full issue URL, owner/repo#N, or repo#N.`,
  );
}

const nwo = (r: IssueRef) => `${r.owner}/${r.repo}`;

// ---------------------------------------------------------------------------
// Project items
// ---------------------------------------------------------------------------

type Item = {
  id: string;
  title: string;
  status?: string;
  class?: string;
  assignees?: string[];
  content?: {
    number: number;
    repository: string;
    url: string;
    type: string;
    body?: string;
    title: string;
  };
};

function listItems(cfg: Config, limit = 400): Item[] {
  const out = gh([
    "project",
    "item-list",
    String(cfg.projectNumber),
    "--owner",
    cfg.org,
    "--format",
    "json",
    "--limit",
    String(limit),
  ]);
  return (JSON.parse(out).items as Item[]) ?? [];
}

/** Find the project item id for a given issue ref (or null if not on board). */
function itemForRef(cfg: Config, ref: IssueRef): Item | null {
  const items = listItems(cfg);
  return (
    items.find((it) => it.content?.url === ref.url) ??
    items.find(
      (it) =>
        it.content?.number === ref.number &&
        it.content?.repository?.toLowerCase() === nwo(ref).toLowerCase(),
    ) ??
    null
  );
}

function setItemField(
  cfg: Config,
  itemId: string,
  field: Field,
  value: string,
): void {
  const project = getProject(cfg);
  let valueArg: string;
  if (field.dataType === "SINGLE_SELECT") {
    const opt = findOption(field, value);
    valueArg = `{ singleSelectOptionId: "${opt.id}" }`;
  } else if (field.dataType === "TEXT") {
    valueArg = `{ text: ${JSON.stringify(value)} }`;
  } else if (field.dataType === "NUMBER") {
    valueArg = `{ number: ${Number(value)} }`;
  } else if (field.dataType === "DATE") {
    valueArg = `{ date: "${value}" }`;
  } else {
    fail(
      `Setting field "${field.name}" (type ${field.dataType}) is not supported via 'set'. ` +
        `Use 'board edit' for issue-native fields like Assignees/Labels/Milestone.`,
    );
  }
  graphql(`
    mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: "${project.id}",
        itemId: "${itemId}",
        fieldId: "${field.id}",
        value: ${valueArg}
      }) { projectV2Item { id } }
    }`);
}

// ---------------------------------------------------------------------------
// Tiny arg parser
// ---------------------------------------------------------------------------

type Args = { _: string[]; flags: Record<string, string | boolean> };

function parseArgs(argv: string[]): Args {
  const _: string[] = [];
  const flags: Record<string, string | boolean> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const eq = a.indexOf("=");
      if (eq !== -1) {
        flags[a.slice(2, eq)] = a.slice(eq + 1);
      } else {
        const next = argv[i + 1];
        if (next === undefined || next.startsWith("--")) {
          flags[a.slice(2)] = true;
        } else {
          flags[a.slice(2)] = next;
          i++;
        }
      }
    } else {
      _.push(a);
    }
  }
  return { _, flags };
}

function flagStr(flags: Args["flags"], key: string): string | undefined {
  const v = flags[key];
  return typeof v === "string" ? v : undefined;
}

/** Body can come from --body, --body-file, or stdin (when --body=- or piped). */
function resolveBody(flags: Args["flags"]): string | undefined {
  const file = flagStr(flags, "body-file");
  if (file) return readFileSync(file, "utf8");
  const body = flagStr(flags, "body");
  if (body === "-") return readFileSync(0, "utf8");
  return body;
}

// ---------------------------------------------------------------------------
// Output helpers
// ---------------------------------------------------------------------------

function fail(msg: string): never {
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}

function jsonOut(flags: Args["flags"]): boolean {
  return flags.json === true;
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

function cmdFields(cfg: Config): void {
  const p = getProject(cfg);
  console.log(`Project: ${p.title} (org ${cfg.org}, #${cfg.projectNumber})\n`);
  for (const f of p.fields) {
    const opts = f.options
      ? "  options: " + f.options.map((o) => o.name).join(" | ")
      : "";
    console.log(`• ${f.name}  [${f.dataType}]${opts ? "\n" + opts : ""}`);
  }
}

function cmdList(cfg: Config, args: Args): void {
  let items = listItems(cfg);
  const match = (a?: string, b?: string) =>
    !b || (a ?? "").toLowerCase().includes(b.toLowerCase());
  const fStatus = flagStr(args.flags, "status");
  const fClass = flagStr(args.flags, "class");
  const fRepo = flagStr(args.flags, "repo");
  const fAssignee = flagStr(args.flags, "assignee");
  items = items.filter(
    (it) =>
      match(it.status, fStatus) &&
      match(it.class, fClass) &&
      match(it.content?.repository, fRepo) &&
      (!fAssignee ||
        (it.assignees ?? []).some((a) =>
          a.toLowerCase().includes(fAssignee.toLowerCase()),
        )),
  );
  if (jsonOut(args.flags)) {
    console.log(JSON.stringify(items, null, 2));
    return;
  }
  if (items.length === 0) {
    console.log("(no matching items)");
    return;
  }
  for (const it of items) {
    const c = it.content;
    const ref = c ? `${c.repository}#${c.number}` : "(draft)";
    const status = it.status ?? "—";
    const cls = it.class ?? "—";
    console.log(`${status.padEnd(16)} ${cls.padEnd(12)} ${ref}`);
    console.log(`   ${it.title}`);
  }
  console.log(`\n${items.length} item(s)`);
}

function cmdView(cfg: Config, args: Args): void {
  const ref = parseRef(cfg, args._[0] ?? fail("usage: board view <ref>"));
  const fields =
    "title,number,state,body,url,labels,assignees,milestone,author,createdAt,comments";
  const data = JSON.parse(
    gh([
      "issue",
      "view",
      String(ref.number),
      "--repo",
      nwo(ref),
      "--json",
      fields,
    ]),
  );
  const item = itemForRef(cfg, ref);
  if (jsonOut(args.flags)) {
    console.log(JSON.stringify({ issue: data, projectItem: item }, null, 2));
    return;
  }
  console.log(`#${data.number}  ${data.title}   [${data.state}]`);
  console.log(data.url);
  console.log(
    `author: ${data.author?.login ?? "?"}   assignees: ${
      (data.assignees ?? []).map((a: any) => a.login).join(", ") || "—"
    }`,
  );
  console.log(
    `labels: ${(data.labels ?? []).map((l: any) => l.name).join(", ") || "—"}`,
  );
  if (item)
    console.log(
      `board:  Status=${item.status ?? "—"}  Class=${item.class ?? "—"}`,
    );
  else console.log("board:  (not on the project board)");
  console.log("\n--- body ---\n" + (data.body || "(empty)"));
  const comments = data.comments ?? [];
  if (comments.length) {
    console.log(`\n--- ${comments.length} comment(s) ---`);
    for (const c of comments) {
      console.log(`\n@${c.author?.login} (${c.createdAt}):`);
      console.log(c.body);
    }
  }
}

function cmdNew(cfg: Config, args: Args): void {
  const repo = flagStr(args.flags, "repo");
  const title = flagStr(args.flags, "title");
  if (!repo) fail("--repo is required (owner/repo or just repo for the org)");
  if (!title) fail("--title is required");
  const fullRepo = repo.includes("/") ? repo : `${cfg.org}/${repo}`;
  const body = resolveBody(args.flags) ?? "";

  const createArgs = [
    "issue",
    "create",
    "--repo",
    fullRepo,
    "--title",
    title,
    "--body",
    body,
  ];
  for (const a of multi(args.flags, "assignee"))
    createArgs.push("--assignee", a);
  for (const l of multi(args.flags, "label")) createArgs.push("--label", l);
  if (flagStr(args.flags, "milestone"))
    createArgs.push("--milestone", flagStr(args.flags, "milestone")!);

  const url = gh(createArgs).split("\n").pop()!.trim();

  // Add to the board.
  const added = JSON.parse(
    gh([
      "project",
      "item-add",
      String(cfg.projectNumber),
      "--owner",
      cfg.org,
      "--url",
      url,
      "--format",
      "json",
    ]),
  );
  const itemId: string = added.id;

  // Set board fields if requested.
  const fieldFlags: Array<[string, string]> = [
    ["status", "Status"],
    ["class", "Class"],
    ["priority", "Lab Priority"],
  ];
  for (const [flag, fieldName] of fieldFlags) {
    const v = flagStr(args.flags, flag);
    if (v) setItemField(cfg, itemId, findField(cfg, fieldName), v);
  }

  if (jsonOut(args.flags)) {
    console.log(JSON.stringify({ url, itemId }, null, 2));
  } else {
    console.log(`created: ${url}`);
    console.log(`added to board (item ${itemId})`);
  }
}

function cmdEdit(cfg: Config, args: Args): void {
  const ref = parseRef(cfg, args._[0] ?? fail("usage: board edit <ref> [flags]"));
  const editArgs = ["issue", "edit", String(ref.number), "--repo", nwo(ref)];
  if (flagStr(args.flags, "title"))
    editArgs.push("--title", flagStr(args.flags, "title")!);
  const body = resolveBody(args.flags);
  if (body !== undefined) editArgs.push("--body", body);
  for (const l of multi(args.flags, "add-label")) editArgs.push("--add-label", l);
  for (const l of multi(args.flags, "remove-label"))
    editArgs.push("--remove-label", l);
  for (const a of multi(args.flags, "add-assignee"))
    editArgs.push("--add-assignee", a);
  for (const a of multi(args.flags, "remove-assignee"))
    editArgs.push("--remove-assignee", a);
  if (flagStr(args.flags, "milestone"))
    editArgs.push("--milestone", flagStr(args.flags, "milestone")!);
  if (editArgs.length === 5)
    fail("nothing to edit — pass --title, --body, --add-label, etc.");
  gh(editArgs);
  console.log(`updated: ${ref.url}`);
}

function cmdComment(cfg: Config, args: Args): void {
  const ref = parseRef(
    cfg,
    args._[0] ?? fail("usage: board comment <ref> --body <text|-|@file>"),
  );
  const body = resolveBody(args.flags);
  if (!body) fail("--body (or --body-file, or --body -) is required");
  gh([
    "issue",
    "comment",
    String(ref.number),
    "--repo",
    nwo(ref),
    "--body",
    body,
  ]);
  console.log(`commented on: ${ref.url}`);
}

function cmdSet(cfg: Config, args: Args, presetField?: string): void {
  const ref = parseRef(cfg, args._[0] ?? fail("usage: board set <ref> <field> <value>"));
  const fieldName = presetField ?? args._[1];
  const value = presetField ? args._.slice(1).join(" ") : args._.slice(2).join(" ");
  if (!fieldName) fail("field name required");
  if (!value) fail("value required");
  const item = itemForRef(cfg, ref);
  if (!item)
    fail(
      `Ticket ${nwo(ref)}#${ref.number} is not on the board. Run: board add ${args._[0]}`,
    );
  const field = findField(cfg, fieldName);
  setItemField(cfg, item.id, field, value);
  console.log(`set ${field.name} = ${value} on ${ref.url}`);
}

function cmdAdd(cfg: Config, args: Args): void {
  const ref = parseRef(cfg, args._[0] ?? fail("usage: board add <ref>"));
  const added = JSON.parse(
    gh([
      "project",
      "item-add",
      String(cfg.projectNumber),
      "--owner",
      cfg.org,
      "--url",
      ref.url,
      "--format",
      "json",
    ]),
  );
  console.log(`added ${ref.url} to board (item ${added.id})`);
}

function cmdState(cfg: Config, args: Args, action: "close" | "reopen"): void {
  const ref = parseRef(cfg, args._[0] ?? fail(`usage: board ${action} <ref>`));
  const a = ["issue", action, String(ref.number), "--repo", nwo(ref)];
  const reason = flagStr(args.flags, "reason");
  if (action === "close" && reason) a.push("--reason", reason);
  gh(a);
  console.log(`${action}d: ${ref.url}`);
}

function multi(flags: Args["flags"], key: string): string[] {
  const v = flags[key];
  if (typeof v !== "string") return [];
  return v.split(",").map((s) => s.trim()).filter(Boolean);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const HELP = `board — manage the DevBoard (GitHub Projects v2) and its issue tickets

USAGE
  board <command> [args] [flags]

COMMANDS
  list                      List board items
    --status S  --class C  --repo R  --assignee A  --json
  view <ref>                Show a ticket: issue body, board fields, comments  [--json]
  new --repo R --title T    Create an issue + add to board
    --body TEXT|-  --body-file F  --assignee a,b  --label l,m  --milestone M
    --status S  --class C  --priority P   (board fields, fuzzy-matched)
  edit <ref>                Edit issue fields
    --title T  --body TEXT|-  --body-file F
    --add-label l,m  --remove-label l  --add-assignee a  --remove-assignee a  --milestone M
  comment <ref>             Add a comment   --body TEXT|-  --body-file F
  set <ref> <field> <val>   Set a board field (Status / Class / Lab Priority / ...)
  status <ref> <val>        Shortcut for: set <ref> Status <val>
  class  <ref> <val>        Shortcut for: set <ref> Class <val>
  priority <ref> <val>      Shortcut for: set <ref> "Lab Priority" <val>
  add <ref>                 Add an existing issue to the board
  close <ref> [--reason completed|not_planned]
  reopen <ref>
  fields                    List board fields and single-select options

REFERENCES (<ref>)
  Full issue URL, or owner/repo#N, or repo#N (org assumed from board.config.json)

EXAMPLES
  board list --status development
  board new --repo controllers --title "Fix actuator" --class action --status development
  board comment controllers#1 --body "Tested, works on rig 2."
  board status controllers#1 done
  board edit controllers#1 --add-label bug --add-assignee kzfubar`;

function main(): void {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
    console.log(HELP);
    return;
  }
  const cfg = loadConfig();
  const args = parseArgs(argv.slice(1));
  switch (cmd) {
    case "list":
      return cmdList(cfg, args);
    case "view":
    case "show":
      return cmdView(cfg, args);
    case "new":
    case "create":
      return cmdNew(cfg, args);
    case "edit":
      return cmdEdit(cfg, args);
    case "comment":
      return cmdComment(cfg, args);
    case "set":
      return cmdSet(cfg, args);
    case "status":
      return cmdSet(cfg, args, "Status");
    case "class":
      return cmdSet(cfg, args, "Class");
    case "priority":
      return cmdSet(cfg, args, "Lab Priority");
    case "add":
      return cmdAdd(cfg, args);
    case "close":
      return cmdState(cfg, args, "close");
    case "reopen":
      return cmdState(cfg, args, "reopen");
    case "fields":
      return cmdFields(cfg);
    default:
      fail(`unknown command "${cmd}". Run 'board help'.`);
  }
}

main();
