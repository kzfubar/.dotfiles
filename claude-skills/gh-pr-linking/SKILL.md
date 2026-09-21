---
name: gh-pr-linking
description: Make a GitHub pull request link to and auto-close the issue it resolves, so the PR appears under "Linked pull requests" and merging closes the issue. Use when opening a PR that fixes an issue, writing a PR body, or debugging why a merged PR did not close its issue or why an issue shows no attached PR. Covers closing keywords, valid same-repo and cross-repo reference syntax, and verifying the link actually landed.
---

# Linking a PR to the issue it closes

For a PR to **link** to an issue (show under "Linked pull requests") and
**auto-close** it on merge, the PR body must contain a closing keyword followed
by a reference GitHub can parse.

```
Closes #8                                   # same-repo PR — preferred
Closes some-org/characterization#8          # cross-repo PR
```

Recognized keywords: `close` / `closes` / `closed`, `fix` / `fixes` / `fixed`,
`resolve` / `resolves` / `resolved`.

Auto-close fires only when the PR merges into the repository's **default
branch**. Merging into a release or feature branch links but does not close.

## The common failure

Writing a `repo#N` shorthand — `Closes characterization#8`. Many CLIs and
internal tools accept that form as an argument, so it looks right. **GitHub does
not parse it.** It renders as plain text, so:

- the PR never links to the issue
- any project board shows no attached PR
- merging does **not** close the issue

Only two forms work in text GitHub renders: `#N` for the same repo, and the
fully-qualified `owner/repo#N` across repos.

One keyword covers one issue. To close several, repeat it: `Closes #8, closes #9`
— a bare `#9` after the first keyword does not inherit it.

## Verify the link landed

Do not assume it worked — check for a cross-referenced event from the PR:

```bash
gh api repos/<owner>/<repo>/issues/<N>/timeline \
  --jq '.[] | select(.event=="cross-referenced") | .source.issue.number'
```

Empty output means the reference did not parse. Fix the PR body and re-check:

```bash
gh pr edit <PR> --body "...Closes #8..."
```

You can also confirm from the issue side — a linked PR appears in the issue's
development sidebar.

## Related caveat

A project board's `Status` field does **not** automatically follow an issue's
open/closed state. That's a Projects workflow setting configured on the project
itself, not something a closing keyword or a CLI does. If a merged PR closed the
issue but the board still shows it in progress, that's the cause.
