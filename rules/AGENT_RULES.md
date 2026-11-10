## Agent toolkit rules

These rules apply to every project and folder on this machine.

### GitHub: `gh-axi`
- Use `gh-axi` instead of plain `gh` for all GitHub work: repos, PRs, issues, releases, workflows, API calls.
- Run `gh-axi --help` (or `gh-axi <command> --help`) for usage. `gh-axi` with no arguments shows a dashboard.

### Browser automation: `chrome-devtools-axi`
- Use `chrome-devtools-axi` for browser automation: opening pages, snapshots, screenshots, clicking, filling forms, console and network inspection, Lighthouse and performance traces.
- Typical flow: `chrome-devtools-axi open <url>`, then `snapshot`, then `click @<uid>` / `fill @<uid> <text>`.

### Pushing code: `no-mistakes`
- Push to GitHub only through no-mistakes, a local git gate that validates code before it reaches the real remote.
- In a repo without the gate, run `no-mistakes init` once.
- Push with `git push no-mistakes <branch>`, or drive it headlessly with `no-mistakes axi run` (see `no-mistakes axi --help`).
- Never bypass the gate (no direct `git push origin`, no `--skip`) unless the user explicitly says so.

### Continuous / long-running work: `gnhf`
- Use `gnhf` for continuous, iterative or long-running agent work (for example, overnight tasks).
- Example: `gnhf --agent claude --max-run-time 2h --worktree "<objective>"`.
- Always set a bound: `--max-iterations`, `--max-tokens`, `--max-run-time` or `--stop-when`.
