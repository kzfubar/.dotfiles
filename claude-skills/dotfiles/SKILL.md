---
name: dotfiles
description: Where personal config, shell aliases, shell functions, and helper scripts live, and how to add them so they survive a new machine. Use when adding or changing an alias, a zsh function, a CLI helper script, a git or vim setting, Claude Code settings, hooks, skills, or CLAUDE.md rules, or when asked to "make a shortcut", "add a helper", "put this in my config", or change anything under ~/.dotfiles. Covers which file each kind of change goes in, linking, and the commit-and-push rule.
---

# Dotfiles

Personal config lives in the git repo `~/.dotfiles` (remote `kzfubar/.dotfiles`). The live files
in `~` are links into it, created by `~/.dotfiles/link.sh` (`link.ps1` on Windows). Edit the repo
copy, never replace a link with a real file.

Read `~/.dotfiles/README.md` for the full layout table and bootstrap steps. The rules for Claude
are in `~/.dotfiles/CLAUDE.md` (linked to `~/.claude/CLAUDE.md`); its **Dotfiles** section is the
source for the commit-and-push rule below.

## Where things go

| Change | File |
|---|---|
| Alias or small shell function | `.zshrc`, with a one-line comment above it like `cl` |
| Standalone helper script | `tools/<name>/<name>`, executable, plus a line in `links` and a row in the README Layout table |
| Git setting | `.gitconfig` (shared) or `.gitconfig.local` (gitignored, per machine) |
| Claude Code settings or permissions | `claude-settings.json` |
| Claude hook | `claude-hooks/`, referenced from `claude-settings.json` |
| Claude skill | `claude-skills/<name>/SKILL.md`; `links` links every directory there |
| Skill loaded only on request | `skills/<name>/SKILL.md`, linked as `~/.skills` |
| Rule for Claude | `CLAUDE.md` |
| macOS app or brew formula | `Brewfile` |

Prefer a script in `tools/` over a zsh function once it has subcommands or more than a few
lines. `tools/tnet/tnet` is the pattern to copy.

## Rules

- The same repo is used on macOS, Ubuntu and Windows (Git Bash). Guard OS-specific commands with
  `case "$(uname -s)"`, and write scripts for bash, not zsh-only syntax. Windows-only setup goes
  in `bootstrap-windows.ps1` or `link.ps1`.
- Machine-specific values or anything secret go in a gitignored file, never the tracked one.
- After adding a line to `links`, re-run `link.sh` (or `link.ps1` on Windows) so it takes effect
  on this machine.
- Check the change works: run the script, or `zsh -ic '<command>'` for `.zshrc` changes.

## Commit and push

Follow the **Dotfiles** section of `~/.dotfiles/CLAUDE.md`: after any change in the repo, commit and
push without asking. Use one commit per logical change in the repo's short lowercase style (e.g.
`tnet: tailnet switch aliases with dns flush`). Commit changes you didn't make separately. Then run
`git push` and confirm with `git status -sb` that the branch is not ahead of `origin`.
