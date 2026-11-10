<#
.SYNOPSIS
  Installs gh-axi, chrome-devtools-axi, no-mistakes and gnhf globally, and
  writes the agent rules that tell coding agents to use them in every project.

.EXAMPLE
  irm https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.ps1 | iex

.EXAMPLE
  # With options:
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.ps1))) -Project
#>
[CmdletBinding()]
param(
  [switch]$Project,     # also write the rules into ./CLAUDE.md and ./AGENTS.md
  [switch]$SkipTools,   # only write rules, don't install tools
  [switch]$SkipRules,   # only install tools, don't write rules
  [switch]$SkipHooks,   # don't run `<axi> setup hooks`
  [switch]$Uninstall,   # remove the rules blocks this script wrote (tools stay installed)
  [switch]$DryRun       # print what would happen, change nothing
)

function Invoke-AgentToolkitInstall {
  param($Project, $SkipTools, $SkipRules, $SkipHooks, $Uninstall, $DryRun)

  $ErrorActionPreference = 'Stop'
  $RepoRaw = if ($env:AGENT_TOOLKIT_RAW) { $env:AGENT_TOOLKIT_RAW } else { 'https://raw.githubusercontent.com/polysius/agent-toolkit/main' }
  $Begin = '<!-- BEGIN agent-toolkit -->'
  $End = '<!-- END agent-toolkit -->'

  function Say($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
  function Ok($msg) { Write-Host "  ok  $msg" -ForegroundColor Green }
  function Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
  function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
  function Run([string]$desc, [scriptblock]$block) {
    if ($DryRun) { Write-Host "  dry-run: $desc"; return }
    & $block
  }
  function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user;$env:Path"
  }

  # ---------- rules ----------
  function Get-Rules {
    $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'rules\AGENT_RULES.md' } else { $null }
    if ($local -and (Test-Path $local)) { return (Get-Content -Raw -Encoding UTF8 $local) }
    return (Invoke-RestMethod "$RepoRaw/rules/AGENT_RULES.md")
  }

  function Set-RulesBlock([string]$file, [string]$rules) {
    $block = "$Begin`n$($rules.Trim())`n$End"
    $content = if (Test-Path $file) { Get-Content -Raw -Encoding UTF8 $file } else { '' }
    if ($null -eq $content) { $content = '' }
    $pattern = [regex]::Escape($Begin) + '[\s\S]*?' + [regex]::Escape($End)
    if ($content -match $pattern) {
      $new = [regex]::Replace($content, $pattern, { param($m) $block })
      $verb = 'updated'
    } else {
      $sep = if ($content.Trim().Length -gt 0) { "`n`n" } else { '' }
      $new = $content.TrimEnd() + $sep + $block + "`n"
      $verb = 'added to'
    }
    Run "write rules block to $file" {
      $dir = Split-Path -Parent $file
      if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
      [IO.File]::WriteAllText($file, $new, (New-Object Text.UTF8Encoding($false)))
    }
    Ok "rules $verb $file"
  }

  function Remove-RulesBlock([string]$file) {
    if (-not (Test-Path $file)) { return }
    $content = Get-Content -Raw -Encoding UTF8 $file
    $pattern = '(\r?\n)*' + [regex]::Escape($Begin) + '[\s\S]*?' + [regex]::Escape($End) + '(\r?\n)?'
    if ($content -notmatch $pattern) { return }
    $new = [regex]::Replace($content, $pattern, "`n").Trim()
    Run "remove rules block from $file" {
      [IO.File]::WriteAllText($file, $(if ($new) { "$new`n" } else { '' }), (New-Object Text.UTF8Encoding($false)))
    }
    Ok "rules removed from $file"
  }

  function Get-RuleTargets {
    $targets = @(Join-Path $HOME '.claude\CLAUDE.md')   # Claude Code: always
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    if (Test-Path $codexHome) { $targets += (Join-Path $codexHome 'AGENTS.md') }
    $gemini = Join-Path $HOME '.gemini'
    if (Test-Path $gemini) { $targets += (Join-Path $gemini 'GEMINI.md') }
    if ($Project) { $targets += (Join-Path (Get-Location) 'CLAUDE.md'), (Join-Path (Get-Location) 'AGENTS.md') }
    return $targets
  }

  # ---------- no-mistakes PR defaults ----------
  # Sets "<key>: <value>" under the top-level "<parent>:" block of a YAML file,
  # replacing an existing value or adding the key (and block) when missing.
  # The block's own child indentation is reused so the mapping stays valid.
  function Set-YamlChild([System.Collections.Generic.List[string]]$lines, [string]$parent, [string]$key, [string]$value) {
    $parentAt = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match "^${parent}:") { $parentAt = $i; break }
    }
    if ($parentAt -lt 0) {
      $lines.Add(''); $lines.Add("${parent}:"); $lines.Add("  ${key}: $value")
      return
    }
    if ($lines[$parentAt] -notmatch "^${parent}:\s*(#.*)?$") {
      Warn "'${parent}:' has an inline value; set ${parent}.${key}: $value by hand"
      return
    }
    # Insert after the block's last indented key, not after trailing comments.
    $indent = ''
    $lastChild = $parentAt
    for ($i = $parentAt + 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^[^\s#]') { break }
      if ($lines[$i] -notmatch '^(\s+)[^\s#]') { continue }
      if (-not $indent) { $indent = $Matches[1] }
      if ($lines[$i] -match "^${indent}${key}:") { $lines[$i] = "${indent}${key}: $value"; return }
      $lastChild = $i
    }
    if (-not $indent) { $indent = '  ' }
    $lines.Insert($lastChild + 1, "${indent}${key}: $value")
  }

  function Set-NoMistakesPrDefaults {
    $nmHome = if ($env:NM_HOME) { $env:NM_HOME } else { Join-Path $HOME '.no-mistakes' }
    $file = Join-Path $nmHome 'config.yaml'
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path $file) { foreach ($l in [IO.File]::ReadAllLines($file)) { $lines.Add($l) } }
    Set-YamlChild $lines 'intent' 'publish_intent' 'false'
    Set-YamlChild $lines 'pr' 'appendix' 'minimal'
    Run "set no-mistakes PR defaults in $file" {
      if (-not (Test-Path $nmHome)) { New-Item -ItemType Directory -Force $nmHome | Out-Null }
      [IO.File]::WriteAllText($file, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
    }
    Ok "no-mistakes PRs: no Intent section, minimal appendix ($file)"
  }

  if ($Uninstall) {
    Say 'Removing agent-toolkit rules blocks'
    foreach ($t in (Get-RuleTargets)) { Remove-RulesBlock $t }
    Say 'Done. The tools themselves are still installed (npm uninstall -g gh-axi chrome-devtools-axi gnhf to remove them).'
    return
  }

  # ---------- tools ----------
  if (-not $SkipTools) {
    Say 'Checking prerequisites'
    if (-not (Has 'git')) { throw 'git is required. Install it from https://git-scm.com and re-run.' }
    Ok 'git'
    if (-not (Has 'npm')) { throw 'Node.js (with npm) is required. Install it from https://nodejs.org and re-run.' }
    Ok "node $(node --version)"

    if (-not (Has 'gh')) {
      if (Has 'winget') {
        Say 'Installing GitHub CLI (gh), required by gh-axi'
        Run 'winget install GitHub.cli' { winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements | Out-Host; Refresh-Path }
      } else {
        Warn 'GitHub CLI (gh) not found and winget is unavailable. Install gh from https://cli.github.com; gh-axi needs it.'
      }
    }
    if (Has 'gh') { Ok 'gh' }

    Say 'Installing gh-axi, chrome-devtools-axi and gnhf (npm, global)'
    Run 'npm install -g gh-axi chrome-devtools-axi gnhf' {
      npm install -g gh-axi chrome-devtools-axi gnhf | Out-Host
      if ($LASTEXITCODE -ne 0) { throw 'npm install -g failed.' }
    }

    if (Has 'no-mistakes') {
      Say 'Updating no-mistakes (already installed)'
      Run 'no-mistakes update --yes' {
        no-mistakes update --yes | Out-Host
        if ($LASTEXITCODE -ne 0) { Warn 'no-mistakes update failed (the installed version still works; try `no-mistakes update` later)' }
      }
    } else {
      Say 'Installing no-mistakes (official installer)'
      Run 'run no-mistakes install.ps1' {
        powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.ps1 | iex" | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'no-mistakes installer failed.' }
        Refresh-Path
      }
    }

    if (-not $SkipHooks) {
      Say 'Installing agent SessionStart hooks for the axi tools'
      foreach ($axi in 'gh-axi', 'chrome-devtools-axi') {
        Run "$axi setup hooks" {
          & $axi setup hooks | Out-Host
          if ($LASTEXITCODE -ne 0) { Warn "$axi setup hooks failed (continuing)" }
        }
      }
    }
  }

  # ---------- rules ----------
  if (-not $SkipRules) {
    Say 'Writing agent rules'
    $rules = Get-Rules
    foreach ($t in (Get-RuleTargets)) { Set-RulesBlock $t $rules }
    Set-NoMistakesPrDefaults
  }

  # ---------- verify ----------
  if (-not $SkipTools -and -not $DryRun) {
    Say 'Verifying'
    $missing = @()
    foreach ($tool in 'gh-axi', 'chrome-devtools-axi', 'no-mistakes', 'gnhf') {
      if (Has $tool) { Ok $tool } else { Warn "$tool not found on PATH (open a new terminal and check again)"; $missing += $tool }
    }
    if ($missing.Count -eq 0) { Say 'All four tools are installed.' }
  }

  Say 'Done. Next: in each repo you push from, run `no-mistakes init` once.'
}

Invoke-AgentToolkitInstall -Project:$Project -SkipTools:$SkipTools -SkipRules:$SkipRules -SkipHooks:$SkipHooks -Uninstall:$Uninstall -DryRun:$DryRun
