# Windows bootstrap: Git, GitHub CLI, Node.js, uv and jq via winget, Claude Code, Claude
# plugins, user-harness, a commit signing key, and links. Safe to re-run. File links need
# Developer Mode; see README.md. For macOS or Ubuntu, use bootstrap-macos or bootstrap-ubuntu.
#
#   powershell -ExecutionPolicy Bypass -File ~\.dotfiles\bootstrap-windows.ps1
$ErrorActionPreference = 'Stop'
$dotfiles = Join-Path $HOME '.dotfiles'

function Step($msg) { Write-Host "`n==> $msg" }

# Runs a native command and stops the bootstrap if it fails.
function Invoke-Checked {
	$command, $rest = $args
	& $command @rest
	if ($LASTEXITCODE -ne 0) { throw "failed (exit $LASTEXITCODE): $args" }
}

function Update-Path {
	$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
		[Environment]::GetEnvironmentVariable('Path', 'User') + ';' + (Join-Path $HOME '.local\bin')
}

if ($PSScriptRoot -ne (Resolve-Path $dotfiles -ErrorAction SilentlyContinue).Path) {
	Write-Error "Clone this repo to $dotfiles first; link.ps1 expects it there."
}

Step 'winget packages'
# The calling shell's PATH can predate an earlier run's installs.
Update-Path
$packages = [ordered]@{ git = 'Git.Git'; gh = 'GitHub.cli'; node = 'OpenJS.NodeJS'; uv = 'astral-sh.uv'; jq = 'jqlang.jq' }
foreach ($command in $packages.Keys) {
	$present = Get-Command $command -ErrorAction SilentlyContinue
	if ($command -eq 'node' -and $present) { $present = [int](node --version).TrimStart('v').Split('.')[0] -ge 24 }
	if ($present) {
		Write-Host "already installed: $command"
	} else {
		winget install --id $packages[$command] --exact --silent --accept-package-agreements --accept-source-agreements
		# -1978335189 (0x8A15002B): already installed with no upgrade available.
		if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget install $($packages[$command]) failed (exit $LASTEXITCODE)" }
		Update-Path
	}
}

Step 'Claude Code'
if (Test-Path (Join-Path $HOME '.local\bin\claude.exe')) {
	Write-Host 'already installed'
} else {
	Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
	Update-Path
}

# Installs the marketplaces and plugins declared in claude-settings.json.
Step 'Claude plugins'
$settings = Get-Content -Raw (Join-Path $dotfiles 'claude-settings.json') | ConvertFrom-Json
foreach ($marketplace in @($settings.extraKnownMarketplaces.PSObject.Properties)) {
	$source = $marketplace.Value.source
	Invoke-Checked claude plugin marketplace add @($source.repo, $source.url, $source.path | Where-Object { $_ })[0]
}
foreach ($plugin in @($settings.enabledPlugins.PSObject.Properties | Where-Object { $_.Value })) {
	Invoke-Checked claude plugin install $plugin.Name
}

# Clones the private user-harness repo and installs its `uh` command. Needs `gh auth login`,
# which happens after the first bootstrap on a fresh machine, so it skips until then.
Step 'user-harness (uh)'
$harness = Join-Path $HOME 'projects\user-harness'
$skipHarness = $false
if (-not (Test-Path (Join-Path $harness '.git'))) {
	# Windows PowerShell turns redirected native stderr into errors, which 'Stop' would throw.
	& { $ErrorActionPreference = 'Continue'; gh auth status *> $null }
	if ($LASTEXITCODE -ne 0) {
		Write-Host 'skipped: run gh auth login, then re-run this bootstrap'
		$skipHarness = $true
	} else {
		Invoke-Checked gh repo clone kzfubar/user-harness $harness
	}
}
if (-not $skipHarness) {
	if (Test-Path (Join-Path $HOME '.local\bin\uh.exe')) {
		Write-Host 'already installed'
	} else {
		Invoke-Checked uv tool install --editable $harness
	}
}

# Windows keeps line endings as committed, and uses gh for HTTPS credentials in place of
# the macOS keychain.
Step 'git identity'
$gitLocal = Join-Path $dotfiles '.gitconfig.local'
if (Test-Path $gitLocal) {
	Write-Host "$gitLocal exists"
} else {
	$stub = "[user]`n  name =`n  email =`n[core]`n  autocrlf = false`n[credential]`n  helper =`n  helper = !gh auth git-credential`n"
	[IO.File]::WriteAllText($gitLocal, $stub)
	Write-Host "Created $gitLocal; fill in name and email."
}

# Commits are signed on every machine. A machine holding the shared GPG key signs with it;
# any other machine gets its own SSH signing key, so private keys never leave the machine
# they were made on. Paths use forward slashes because git reads them.
Step 'commit signing'
$sshDir = (Join-Path $HOME '.ssh') -replace '\\', '/'
$key = "$sshDir/id_ed25519_signing"
$signers = "$sshDir/allowed_signers"
$gpgKey = git config --file (Join-Path $dotfiles '.gitconfig') user.signingkey
$hasGpgKey = $false
if (-not (git config --file $gitLocal gpg.format)) {
	if (Get-Command gpg -ErrorAction SilentlyContinue) {
		& { $ErrorActionPreference = 'Continue'; gpg --list-secret-keys $gpgKey *> $null }
		$hasGpgKey = $LASTEXITCODE -eq 0
	}
	if ($hasGpgKey) {
		Write-Host "signing with GPG key $gpgKey"
	} else {
		if (-not (Test-Path $key)) {
			New-Item -ItemType Directory -Force $sshDir | Out-Null
			# Windows PowerShell drops empty arguments, so the empty passphrase is passed as "".
			Invoke-Checked ssh-keygen -q -t ed25519 -N '""' -C "git signing $env:COMPUTERNAME" -f $key
		}
		Invoke-Checked git config --file $gitLocal gpg.format ssh
		Invoke-Checked git config --file $gitLocal user.signingkey "$key.pub"
		Invoke-Checked git config --file $gitLocal gpg.ssh.allowedSignersFile $signers
		Write-Host "Signing with $key. Add it to GitHub as a signing key (README step 2)."
	}
} else {
	Write-Host "configured in $gitLocal"
}

# allowed_signers lets `git log --show-signature` verify this machine's commits locally.
if (-not $hasGpgKey -and (Test-Path "$key.pub")) {
	$email = git config --file $gitLocal user.email
	$publicKey = (Get-Content "$key.pub").Trim()
	if (-not $email) {
		Write-Host "Fill in user.email in $gitLocal and re-run to record the key in $signers."
	} elseif (-not ((Test-Path $signers) -and (Select-String -Quiet -SimpleMatch $publicKey.Split(' ')[1] $signers))) {
		[IO.File]::AppendAllText($signers, "$email namespaces=`"git`" $publicKey`n")
	}
}

Step 'gh-board config'
$board = Join-Path $dotfiles 'tools\gh-board\board.config.json'
if (Test-Path $board) {
	Write-Host "$board exists"
} else {
	Copy-Item (Join-Path $dotfiles 'tools\gh-board\board.config.example.json') $board
	Write-Host "Created $board; fill in org and projectNumber."
}

Step 'links'
& (Join-Path $dotfiles 'link.ps1')

Step 'Done. Manual steps are in README.md.'
