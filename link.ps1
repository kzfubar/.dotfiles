# Creates the links listed in links: junctions for directories, symbolic links for files.
# Existing files that aren't links are left alone. File links need Developer Mode
# (Settings > System > For developers) or an elevated shell.
$ErrorActionPreference = 'Stop'
$dotfiles = Join-Path $HOME '.dotfiles'

function Test-CanSymlink {
	$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
	$devMode = (Get-ItemProperty $key -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
	$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
		[Security.Principal.WindowsBuiltInRole]::Administrator)
	$devMode -or $admin
}

function Link($src, $dst) {
	$src = [IO.Path]::GetFullPath($src)
	$item = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
	if ($item -and -not $item.LinkType) {
		Write-Host "skip: $dst exists (not a link)"
		return
	}
	if ($item -and @($item.Target)[0] -eq $src) { return }
	# Delete() without arguments removes only the link, never the directory it points to.
	if ($item) { $item.Delete() }
	if ((Get-Item -LiteralPath $src).PSIsContainer) {
		New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
	} else {
		# Windows PowerShell's New-Item demands elevation even in Developer Mode; mklink doesn't.
		cmd /c mklink "$dst" "$src" | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "mklink failed for $dst" }
	}
	Write-Host "linked: $dst"
}

if (-not (Test-CanSymlink)) {
	Write-Error 'File links need Developer Mode: turn it on in Settings > System > For developers, then re-run.'
}

foreach ($line in Get-Content (Join-Path $dotfiles 'links')) {
	if ($line -match '^\s*(#|$)') { continue }
	$src, $dst, $only = -split $line
	if ($only -eq 'unix') { continue }
	$target = Join-Path $HOME $dst
	if ($src.EndsWith('/*')) {
		New-Item -ItemType Directory -Force $target | Out-Null
		foreach ($dir in Get-ChildItem -Directory (Join-Path $dotfiles $src.TrimEnd('*'))) {
			Link $dir.FullName (Join-Path $target $dir.Name)
		}
	} else {
		New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
		Link (Join-Path $dotfiles $src) $target
	}
}
