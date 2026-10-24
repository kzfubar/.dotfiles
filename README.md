# dotfiles

Setup for a new machine: shell, git, vim, Claude Code, and (on macOS) apps via Homebrew.

The repo must be cloned to `~/.dotfiles`; `link.sh`, `link.ps1` and the configs expect that path.

```sh
git clone https://github.com/kzfubar/.dotfiles.git ~/.dotfiles
```

HTTPS because SSH keys aren't set up yet on a fresh machine. Switch afterwards with
`git -C ~/.dotfiles remote set-url origin git@github.com:kzfubar/.dotfiles.git`.

## macOS

```sh
~/.dotfiles/bootstrap-macos
```

Installs the Xcode Command Line Tools, Homebrew, everything in `Brewfile`, oh-my-zsh with zsh-z,
and Claude Code, points gpg-agent at `pinentry-mac`, then runs `link.sh`. Safe to re-run, but re-runs
also upgrade any outdated Brewfile entries.

## Ubuntu

```sh
sudo apt-get install -y git curl
~/.dotfiles/bootstrap-ubuntu
```

Command-line setup only: apt basics (zsh, vim, direnv, jq, gnupg, build tools), GitHub CLI,
current Node.js (NodeSource), uv, oh-my-zsh with zsh-z, and Claude Code; sets zsh as the login
shell and runs `link.sh`. The Brewfile's apps and services are macOS-only. Safe to re-run.

## Windows

Turn on Developer Mode first (Settings > System > For developers): linking a file needs it, or an
elevated shell. Clone with Git for Windows (`winget install Git.Git`), then in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File ~\.dotfiles\bootstrap-windows.ps1
```

Installs Git, GitHub CLI, Node.js, uv, jq, mise, PowerShell 7, Starship and zoxide with winget, and
Claude Code with its own installer, then runs `link.ps1`: junctions for directories, symbolic links
for files. Like `link.sh`, it skips files that already exist, so move an existing `~/.gitconfig`,
`~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.bashrc` or PowerShell profile aside first.
Safe to re-run.

There is no zsh on Windows. Git Bash is the shell, and Windows Terminal's default (the bootstrap
sets it, unless another default was already picked): `.bashrc` loads the same aliases and functions
as `.zshrc` (`shell/common.sh`), with mise, zoxide's `z` in place of zsh-z, and a Starship prompt
styled after robbyrussell. PowerShell 7 is the second shell, for Windows itself; its profile, shared
with Windows PowerShell 5.1, loads mise, `z` and the same prompt, and makes `vim` Git for Windows'
vim. The bootstrap sets the execution policy to RemoteSigned for the user so the profile runs.

## After bootstrapping

1. **Git identity.** Fill in `name` and `email` in `~/.dotfiles/.gitconfig.local` (gitignored).
   On Ubuntu and Windows this file also swaps the macOS keychain credential helper for `gh`; on
   Windows it also sets `core.autocrlf = false`, overriding Git for Windows' default.
2. **Commit signing.** Every commit is signed. A machine holding GPG key
   `44240957A9B01A730B273007F71DA10F3A0DEEB2` signs with it; any other machine gets its own SSH
   signing key from the bootstrap, `~/.ssh/id_ed25519_signing`, set in `.gitconfig.local`. Private
   keys are never copied between machines. Register a new key on GitHub once, so its commits show
   as Verified, before pushing anything signed with it:
   ```sh
   gh auth refresh -h github.com -s admin:ssh_signing_key
   gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing --title "<machine name>"
   ```
   If the bootstrap ran before `user.email` was filled in, re-run it to record the key in
   `~/.ssh/allowed_signers`, which `git log --show-signature` uses.
3. **SSH keys.** Copy or generate them in `~/.ssh`.
4. **GitHub CLI.** Run `gh auth login`. Skip `gh auth setup-git`: it writes to `~/.gitconfig`,
   which is a symlink into this repo. Then re-run the bootstrap: it clones the private
   `kzfubar/user-harness` repo to `~/projects/user-harness` and installs its `uh` command, a step it
   skips until `gh` is logged in.
5. **iTerm (macOS).** Enable iTerm's Claude Code integration so `~/.config/iterm2/cc-status`
   exists; the Claude hooks skip it until then.
6. **gh-board.** Fill in `org` and `projectNumber` in `~/.dotfiles/tools/gh-board/board.config.json`
   (gitignored), or set `BOARD_ORG` / `BOARD_PROJECT`. Needs `gh auth login` with the `project`,
   `repo`, and `read:org` scopes.
7. Open a new terminal.

## Layout

The links are listed once, in `links`, which both `link.sh` and `link.ps1` read. For `source/*`
entries, both also remove links whose target in the source is gone, so a moved or deleted skill
doesn't leave a dangling link behind.

| File | Linked to |
|---|---|
| `.zshrc` | `~/.zshrc` (not on Windows) |
| `shell/common.sh` | Sourced by `.zshrc` and `.bashrc`: shared aliases and functions |
| `.bashrc`, `.bash_profile` | `~/.bashrc`, `~/.bash_profile` (Windows only, Git Bash) |
| `starship.toml` | `~/.config/starship.toml` (Windows only) |
| `powershell/profile.ps1` | `~/Documents/PowerShell/` and `~/Documents/WindowsPowerShell/` `Microsoft.PowerShell_profile.ps1` (Windows only) |
| `.vimrc` | `~/.vimrc` |
| `.gitconfig` | `~/.gitconfig` (includes `.gitconfig.local` last) |
| `.gitignore_global` | `~/.gitignore_global` |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude-settings.json` | `~/.claude/settings.json` |
| `claude-hooks/` | Referenced from `claude-settings.json` |
| `claude-skills/*` | `~/.claude/skills/*`, one link per skill |
| `skills/` | `~/.skills`, skills loaded only on request |
| `tools/gh-board/board` | `~/.local/bin/board` |
| `tools/tnet/tnet` | `~/.local/bin/tnet` |
| `tools/gform/gform` | `~/.local/bin/gform` |
| `Brewfile` | Used by `bootstrap-macos` |

Because these are links, tools that write to them (`git config --global`, Claude Code's
`/config`) edit the repo copy. Review `git status` here after changing settings.
