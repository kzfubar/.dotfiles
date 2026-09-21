# Rules of engagement

Personal defaults across all projects. A project's own CLAUDE.md overrides these on conflict.

## Commits

- Never attribute a commit to Claude. No `Co-Authored-By: Claude`, no "Generated with Claude Code",
  no session links, no mention of Claude or AI anywhere in the message.
- Match the style of the surrounding log rather than imposing a convention on it.

## Comments

- Comments describe what the code does now, not what changed about it.
- Never narrate a diff or track transient state: "updated to use the new API", "previously returned
  a list", "TODO: remove after migration", "now handles the null case".
- If a comment would be stale once the change is merged, don't write it.

## Pushback

- Raise an objection before doing the work, not after.
- When the disagreement is about a checkable fact, cite the specific source: file and line, a doc
  URL, or command output. Never cite something you have not actually read this session.
- When it's judgment rather than fact, say so plainly instead of dressing it up as a citation.
- One clear objection. If I confirm, proceed with the full request and don't re-litigate.

## Verification

- Don't report work as done because it looks right. Run the test, build, or linter and show the
  output.
- If something can't be verified, say so explicitly rather than implying it was checked.

## Python tooling

- Use `uv` for everything: `uv run`, `uv add`, `uv add --dev`, `uv sync`. Never `pip install`,
  `python -m venv`, or a hand-edited dependency list in `pyproject.toml`.

## Secrets and .env

- `.env` and friends are blocked from reading on purpose. That is the intended behavior, not an
  obstacle to work around — never reach for a subprocess to read one.
- To add a key, append it through the shell with an empty value and tell me to fill it in:
  `printf 'NEW_KEY=\n' >> .env`. Add the same key to the committed `.env.example` in the same pass.
- To change a value, target the key by name: `sed -i '' 's/^KEY=.*/KEY=newvalue/' .env`. Don't read
  the file to find it first.
- Never print, echo, or summarize the contents of a `.env`, and never ask me to paste a credential
  into the chat. If a command fails on credentials, say which key is missing and stop.

## Scope

- Do what I asked. If you notice adjacent problems, mention them; don't fix them unprompted.
