# dotfiles

Setup for a new machine: shell, git, vim, Claude Code, and (on macOS) apps via Homebrew.

The repo must be cloned to `~/.dotfiles`; `link` and the configs expect that path.

```sh
git clone https://github.com/kzfubar/dotfiles.git ~/.dotfiles
```

HTTPS because SSH keys aren't set up yet on a fresh machine. Switch afterwards with
`git -C ~/.dotfiles remote set-url origin git@github.com:kzfubar/dotfiles.git`.

## macOS

```sh
~/.dotfiles/bootstrap-macos
```

Installs the Xcode Command Line Tools, Homebrew, everything in `Brewfile`, oh-my-zsh with zsh-z,
and Claude Code, points gpg-agent at `pinentry-mac`, then runs `link`. Safe to re-run, but re-runs
also upgrade any outdated Brewfile entries.

## Ubuntu

```sh
sudo apt-get install -y git curl
~/.dotfiles/bootstrap-ubuntu
```

Command-line setup only: apt basics (zsh, vim, direnv, jq, gnupg, build tools), GitHub CLI,
current Node.js (NodeSource), uv, oh-my-zsh with zsh-z, and Claude Code; sets zsh as the login
shell and runs `link`. The Brewfile's apps and services are macOS-only. Safe to re-run.

## After bootstrapping

1. **Git identity.** Fill in `name` and `email` in `~/.dotfiles/.gitconfig_local` (gitignored).
   On Ubuntu this file also swaps the macOS keychain credential helper for `gh`.
2. **GPG signing.** Commits are signed with key `44240957A9B01A730B273007F71DA10F3A0DEEB2`, so
   commits fail until it's imported: export with `gpg --export-secret-keys --armor <key>` on the
   old machine, then `gpg --import` on the new one.
3. **SSH keys.** Copy or generate them in `~/.ssh`.
4. **GitHub CLI.** Run `gh auth login`. Skip `gh auth setup-git`: it writes to `~/.gitconfig`,
   which is a symlink into this repo.
5. **iTerm (macOS).** Enable iTerm's Claude Code integration so `~/.config/iterm2/cc-status`
   exists; the Claude hooks skip it until then.
6. **gh-board.** Fill in `org` and `projectNumber` in `~/.dotfiles/tools/gh-board/board.config.json`
   (gitignored), or set `BOARD_ORG` / `BOARD_PROJECT`. Needs `gh auth login` with the `project`,
   `repo`, and `read:org` scopes.
7. Open a new terminal.

## Layout

| File | Linked to |
|---|---|
| `.zshrc` | `~/.zshrc` |
| `.vimrc` | `~/.vimrc` |
| `.gitconfig` | `~/.gitconfig` (includes `.gitconfig_local` last) |
| `.gitignore_global` | `~/.gitignore_global` |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude-settings.json` | `~/.claude/settings.json` |
| `claude-hooks/` | Referenced from `claude-settings.json` |
| `claude-skills/*` | `~/.claude/skills/*`, one link per skill |
| `tools/gh-board/board` | `~/.local/bin/board` |
| `Brewfile` | Used by `bootstrap-macos` |

Because these are symlinks, tools that write to them (`git config --global`, Claude Code's
`/config`) edit the repo copy. Review `git status` here after changing settings.
