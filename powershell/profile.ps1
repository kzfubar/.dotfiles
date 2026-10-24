# Profile for PowerShell 7 and Windows PowerShell 5.1; link.ps1 links it for both.

$env:EDITOR = 'vim'
# Git for Windows' vim, which reads ~/.vimrc as it does in Git Bash
Set-Alias vim (Join-Path $env:ProgramFiles 'Git\usr\bin\vim.exe')
Set-Alias g git

# mise: tools pinned by a project's mise.toml. PowerShell 7 updates PATH on cd; 5.1 can't, so it
# uses mise's shims, which pick the version when a tool runs.
if (Get-Command mise -ErrorAction SilentlyContinue) {
	$shims = if ($PSVersionTable.PSVersion.Major -lt 7) { '--shims' }
	# empty when the shims are already on PATH, as on a second `. $PROFILE`
	$init = mise activate pwsh $shims | Out-String
	if ($init.Trim()) { Invoke-Expression $init }
}
if (Get-Command starship -ErrorAction SilentlyContinue) { starship init powershell | Out-String | Invoke-Expression }
# z <part of a dir>: jump to a frequently used directory, like zsh-z; last, as zoxide asks
if (Get-Command zoxide -ErrorAction SilentlyContinue) { zoxide init powershell | Out-String | Invoke-Expression }
