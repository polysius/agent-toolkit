# agent-toolkit

One install that sets up four tools for coding agents. It also tells your agents to use those tools in every project on the machine.

| Job | Tool | Why |
| --- | --- | --- |
| GitHub | [`gh-axi`](https://www.npmjs.com/package/gh-axi) | Agent-friendly, token-efficient wrapper around `gh` |
| Browser automation | [`chrome-devtools-axi`](https://www.npmjs.com/package/chrome-devtools-axi) | Drive Chrome DevTools from an agent |
| Pushing code | [`no-mistakes`](https://github.com/kunchenguid/no-mistakes) | Local git gate that validates code before it reaches GitHub |
| Long-running work | [`gnhf`](https://github.com/kunchenguid/gnhf) | Runs an agent in a loop on a bounded objective |

## What it does

1. Installs the four tools **globally**: the three npm packages with `npm install -g`, and no-mistakes with its official installer (or `no-mistakes update --yes` if it's already installed). It also installs the GitHub CLI if it's missing, because `gh-axi` needs it.
2. Runs `gh-axi setup hooks` and `chrome-devtools-axi setup hooks`, so agents get the tools' context when a session starts.
3. Writes [the rules](rules/AGENT_RULES.md) into your **global** agent instruction files, so they apply in every folder:
   - `~/.claude/CLAUDE.md` (Claude Code)
   - `~/.codex/AGENTS.md` (Codex), if `~/.codex` exists
   - `~/.gemini/GEMINI.md` (Gemini CLI), if `~/.gemini` exists

The rules go between `<!-- BEGIN agent-toolkit -->` and `<!-- END agent-toolkit -->` markers. Re-running the installer updates that block in place, and anything else in those files is left alone.

**Prerequisites:** git and Node.js (with npm). On macOS and Linux you also need curl.

## Install, option 1: one command

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.ps1 | iex
```

**macOS / Linux**

```sh
curl -fsSL https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.sh | sh
```

## Install, option 2: ask your agent

Paste this into Claude Code, Codex or any other coding agent:

```text
Install agent-toolkit on this machine by following the instructions at
https://raw.githubusercontent.com/polysius/agent-toolkit/main/AGENT_INSTALL.md
```

## Options

| PowerShell | sh | Effect |
| --- | --- | --- |
| `-Project` | `--project` | Also write the rules into `./CLAUDE.md` and `./AGENTS.md` of the current folder (useful to commit them into a repo for teammates) |
| `-SkipTools` | `--skip-tools` | Only write the rules |
| `-SkipRules` | `--skip-rules` | Only install the tools |
| `-SkipHooks` | `--skip-hooks` | Don't install the axi SessionStart hooks |
| `-Uninstall` | `--uninstall` | Remove the rules blocks (the tools stay installed) |
| `-DryRun` | `--dry-run` | Show what would happen without changing anything |

How to pass options with the one-line install:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.ps1))) -Project
```

```sh
curl -fsSL https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.sh | sh -s -- --project
```

## After installing

- In each repo you push from, run `no-mistakes init` once. After that, push with `git push no-mistakes <branch>`.
- Run `gh-axi`, `chrome-devtools-axi`, `no-mistakes` or `gnhf` with `--help` to see each tool's commands.

## Notes

- no-mistakes release binaries send anonymous telemetry by default. Set `NO_MISTAKES_TELEMETRY=0` to turn it off. See the [no-mistakes install docs](https://kunchenguid.github.io/no-mistakes/start-here/installation/).
- Each tool belongs to its own author. This repo only installs and configures them.

## Uninstall

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.ps1))) -Uninstall
npm uninstall -g gh-axi chrome-devtools-axi gnhf
```

```sh
curl -fsSL https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.sh | sh -s -- --uninstall
npm uninstall -g gh-axi chrome-devtools-axi gnhf
```

To remove no-mistakes itself, follow [its uninstall guide](https://kunchenguid.github.io/no-mistakes/start-here/installation/).

## License

MIT
