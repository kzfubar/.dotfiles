---
name: cerebro
description: Connect a project to cerebro, the user's local decision desk and command center, or detach it; and route decisions to it. Use when asked to "connect to cerebro", "add cerebro", "detach from cerebro", to install or update a cerebro kit, when a project's work needs a decision only the user can make (a trade-off, money, priorities, scope, anything irreversible) and the project is not yet connected, or when asked to "ask Kevin", "raise a decision", "submit to cerebro" or "check for answers". In a connected project the installed `cerebro-decisions` skill (and other `cerebro-*` kits) carry the details.
---

# cerebro

cerebro is the user's decision desk and command center on this machine (http://127.0.0.1:8770, always on). Projects
**submit** decisions over REST, the user answers them in one web page, and projects **fetch** the answers and record
them in their own tickets. Features are opt-in kits: `decisions` today, `design` (a C4 architecture view) next. The
source, README and design live in `~/projects/cerebro` (ask the user if it is not there).

## Rules

- **The project is the master.** Its tickets hold the decisions and answers; cerebro holds a copy.
- **cerebro is optional.** If it is not running (`curl -s http://127.0.0.1:8770/api/v1/health`), say so in one line
  and carry on as the project normally would. Never start, restart or deploy cerebro yourself.
- **Answers come only from the user, through cerebro's page.** Never write or guess an answer, and never call
  cerebro's `/api/v1/ui/...` routes.

## Is this project connected?

It is if it has `cerebro.toml` and `.cerebro/lock.json`. Then use the installed skills (`cerebro-decisions`, and any
other `cerebro-*`) and its client, `python .cerebro/cerebro_client.py`; nothing below is needed except updating.

## Connect a project

From the project's root, on a branch (the kit files are committed with the project):

```sh
curl -s http://127.0.0.1:8770/api/v1/client \
  | python -c "import json,sys; open('/tmp/cerebro_client.py','w',newline='\n').write(json.load(sys.stdin)['content'])"
python /tmp/cerebro_client.py kit add decisions --project <name>     # --dry-run first to see what it writes
```

`<name>` is the project's name in cerebro (letters, digits, `.`, `_`, `-`). This writes `cerebro.toml`, the client at
`.cerebro/cerebro_client.py`, `.cerebro/lock.json`, the `cerebro-decisions` skill under `.claude/skills/` and
`.claude/rules/cerebro.md`; it never edits AGENTS.md or CLAUDE.md. If the project already has its own cerebro client
copy (an older connection), `kit add` names it and leaves it; move the project's converter to the new client, then
delete the old copy. Commit the new files.

## Update, remove, detach

```sh
python .cerebro/cerebro_client.py kit update            # kits and client; a file you changed gets <file>.new beside it
python .cerebro/cerebro_client.py kit remove <feature>
python .cerebro/cerebro_client.py detach --dry-run       # then without --dry-run
```

`detach` removes cerebro from both sides: it stops while answers or drafts wait in cerebro (record or discard them
first, or pass `--yes`), moves the project's data in cerebro to its trash (restorable), and deletes every file the
kits installed, keeping files the project changed unless `--force`. The project's converter and its tickets stay.
