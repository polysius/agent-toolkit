# Agent install instructions

You are a coding agent asked to install **agent-toolkit** on this machine. Follow these steps in order, tell the user what you are doing at each step, and stop to ask them if any step fails.

## 1. Check prerequisites

- `git` must be installed.
- Node.js with `npm` must be installed (`node --version`, `npm --version`).
- The GitHub CLI `gh` must be installed, because `gh-axi` drives it. If it's missing, install it with the system package manager (`winget install --id GitHub.cli -e` on Windows, `brew install gh` on macOS, the distro package or https://cli.github.com on Linux), or ask the user.

If git or Node.js is missing, stop and ask the user to install it.

## 2. Install the four tools globally

```sh
npm install -g gh-axi chrome-devtools-axi gnhf
```

Then install no-mistakes with its official installer:

- Windows (PowerShell): `irm https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.ps1 | iex`
- macOS / Linux: `curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh`

## 3. Install the axi agent hooks

```sh
gh-axi setup hooks
chrome-devtools-axi setup hooks
```

## 4. Write the rules into the global agent instruction files

Fetch the rules from https://raw.githubusercontent.com/polysius/agent-toolkit/main/rules/AGENT_RULES.md.

Wrap them in these exact marker lines, so a later run can update them instead of duplicating them:

```
<!-- BEGIN agent-toolkit -->
...contents of AGENT_RULES.md...
<!-- END agent-toolkit -->
```

Write the block to each of these files. If a file already has a block between those markers, replace that block. Otherwise append the block to the end of the file, and keep everything else in the file unchanged:

- `~/.claude/CLAUDE.md` (always; create it if needed)
- `~/.codex/AGENTS.md` (or `$CODEX_HOME/AGENTS.md`), only if that directory exists
- `~/.gemini/GEMINI.md`, only if `~/.gemini` exists

If the user asked for a project install too, also write the block to `CLAUDE.md` and `AGENTS.md` in the current project folder.

## 5. Verify and report

Confirm that `gh-axi`, `chrome-devtools-axi`, `no-mistakes` and `gnhf` all resolve on PATH and print their `--version`. Tell the user which files you wrote the rules to. Remind them to run `no-mistakes init` once in each repo they push from.
