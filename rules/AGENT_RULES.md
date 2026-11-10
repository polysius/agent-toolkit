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

### Writing code: readability first
- Readable code comes before everything else: before cleverness, brevity and micro-optimization.
- Follow the established best practices and conventions of the language, framework and project.
- Write relatable code that a new teammate can follow on first read: clear names, small focused functions, plain control flow, and comments that explain why rather than what.

### Pull request descriptions
- Describe what changed and why, in plain language.
- Do not include an "Intent" section.
- Do not include a "Generated with Claude Code" line or any other note that an AI or LLM wrote the change or the description.
- Do not use emoji.
- Use few or no adverbs.
- Do not use dashes as punctuation. Prefer short paragraphs to long dash bullet lists.
- Do not end with a pipeline or validation report section.
- For no-mistakes PRs, the installer sets `intent.publish_intent: false` and `pr.appendix: minimal` in `~/.no-mistakes/config.yaml`. After the pipeline opens a PR, read its description and edit it to follow these rules.
