#!/bin/sh
# Installs gh-axi, chrome-devtools-axi, no-mistakes and gnhf globally, and
# writes the agent rules that tell coding agents to use them in every project.
#
#   curl -fsSL https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/polysius/agent-toolkit/main/install.sh | sh -s -- --project
#
# Options: --project --skip-tools --skip-rules --skip-hooks --uninstall --dry-run
set -eu

REPO_RAW="${AGENT_TOOLKIT_RAW:-https://raw.githubusercontent.com/polysius/agent-toolkit/main}"
BEGIN='<!-- BEGIN agent-toolkit -->'
END='<!-- END agent-toolkit -->'

PROJECT=0 SKIP_TOOLS=0 SKIP_RULES=0 SKIP_HOOKS=0 UNINSTALL=0 DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --project) PROJECT=1 ;;
    --skip-tools) SKIP_TOOLS=1 ;;
    --skip-rules) SKIP_RULES=1 ;;
    --skip-hooks) SKIP_HOOKS=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,9p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m  ok  %s\033[0m\n' "$1"; }
warn() { printf '\033[33m  !!  %s\033[0m\n' "$1"; }
die()  { printf '\033[31merror: %s\033[0m\n' "$1" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }
run()  { if [ "$DRY_RUN" = 1 ]; then echo "  dry-run: $*"; else "$@"; fi; }

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t agent-toolkit)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# ---------- rules ----------
get_rules() {
  script_dir=""
  case "$0" in */*) script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)" ;; esac
  if [ -n "$script_dir" ] && [ -f "$script_dir/rules/AGENT_RULES.md" ]; then
    cat "$script_dir/rules/AGENT_RULES.md"
  else
    curl -fsSL "$REPO_RAW/rules/AGENT_RULES.md"
  fi
}

# Print $1 with the agent-toolkit block removed.
strip_block() {
  [ -f "$1" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$1"
}

set_rules_block() {
  file="$1"; rules_file="$2"
  if [ -f "$file" ] && grep -qxF "$BEGIN" "$file" && grep -qxF "$END" "$file"; then
    awk -v b="$BEGIN" -v e="$END" -v rf="$rules_file" '
      $0 == b { print; while ((getline l < rf) > 0) print l; skip = 1; next }
      $0 == e { skip = 0 }
      !skip { print }
    ' "$file" > "$TMP/new"
  else
    {
      [ -f "$file" ] && awk 'NF { last = NR } { line[NR] = $0 } END { for (i = 1; i <= last; i++) print line[i] }' "$file"
      if [ -s "$file" ] && [ -n "$(tr -d '[:space:]' < "$file")" ]; then echo; fi
      echo "$BEGIN"
      cat "$rules_file"
      echo "$END"
    } > "$TMP/new"
  fi
  if [ "$DRY_RUN" = 1 ]; then echo "  dry-run: write rules block to $file"; else
    mkdir -p "$(dirname "$file")"
    cp "$TMP/new" "$file"
  fi
  ok "rules written to $file"
}

remove_rules_block() {
  file="$1"
  [ -f "$file" ] || return 0
  grep -qF "$BEGIN" "$file" || return 0
  strip_block "$file" | awk 'NF { last = NR } { line[NR] = $0 } END { for (i = 1; i <= last; i++) print line[i] }' > "$TMP/new"
  if [ "$DRY_RUN" = 1 ]; then echo "  dry-run: remove rules block from $file"; else cp "$TMP/new" "$file"; fi
  ok "rules removed from $file"
}

rule_targets() {
  echo "$HOME/.claude/CLAUDE.md"
  codex_home="${CODEX_HOME:-$HOME/.codex}"
  [ -d "$codex_home" ] && echo "$codex_home/AGENTS.md"
  [ -d "$HOME/.gemini" ] && echo "$HOME/.gemini/GEMINI.md"
  if [ "$PROJECT" = 1 ]; then echo "$(pwd)/CLAUDE.md"; echo "$(pwd)/AGENTS.md"; fi
  return 0
}

if [ "$UNINSTALL" = 1 ]; then
  say "Removing agent-toolkit rules blocks"
  rule_targets | while IFS= read -r t; do remove_rules_block "$t"; done
  say "Done. The tools are still installed (npm uninstall -g gh-axi chrome-devtools-axi gnhf to remove them)."
  exit 0
fi

# ---------- tools ----------
if [ "$SKIP_TOOLS" = 0 ]; then
  say "Checking prerequisites"
  has git || die "git is required. Install it and re-run."
  ok "git"
  has curl || die "curl is required. Install it and re-run."
  has npm || die "Node.js (with npm) is required. Install it from https://nodejs.org and re-run."
  ok "node $(node --version)"

  if ! has gh; then
    if has brew; then
      say "Installing GitHub CLI (gh), required by gh-axi"
      run brew install gh
    else
      warn "GitHub CLI (gh) not found. Install it from https://cli.github.com; gh-axi needs it."
    fi
  fi
  has gh && ok "gh"

  say "Installing gh-axi, chrome-devtools-axi and gnhf (npm, global)"
  NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo /usr/local)"
  if [ -w "$NPM_PREFIX" ] || [ -w "$NPM_PREFIX/lib" ] 2>/dev/null; then
    run npm install -g gh-axi chrome-devtools-axi gnhf
  elif has sudo; then
    warn "npm global prefix ($NPM_PREFIX) is not writable; using sudo"
    run sudo npm install -g gh-axi chrome-devtools-axi gnhf
  else
    die "npm global prefix ($NPM_PREFIX) is not writable. Fix npm permissions and re-run."
  fi

  if has no-mistakes; then
    say "Updating no-mistakes (already installed)"
    run no-mistakes update --yes || warn "no-mistakes update failed (the installed version still works; try 'no-mistakes update' later)"
  else
    say "Installing no-mistakes (official installer)"
    if [ "$DRY_RUN" = 1 ]; then echo "  dry-run: run no-mistakes install.sh"; else
      curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
    fi
  fi
  export PATH="$HOME/.local/bin:$HOME/.no-mistakes/bin:$PATH"

  if [ "$SKIP_HOOKS" = 0 ]; then
    say "Installing agent SessionStart hooks for the axi tools"
    for axi in gh-axi chrome-devtools-axi; do
      run "$axi" setup hooks || warn "$axi setup hooks failed (continuing)"
    done
  fi
fi

# ---------- rules ----------
if [ "$SKIP_RULES" = 0 ]; then
  say "Writing agent rules"
  get_rules > "$TMP/rules.md"
  [ -s "$TMP/rules.md" ] || die "could not load rules/AGENT_RULES.md"
  rule_targets | while IFS= read -r t; do set_rules_block "$t" "$TMP/rules.md"; done
fi

# ---------- verify ----------
if [ "$SKIP_TOOLS" = 0 ] && [ "$DRY_RUN" = 0 ]; then
  say "Verifying"
  missing=0
  for tool in gh-axi chrome-devtools-axi no-mistakes gnhf; do
    if has "$tool"; then ok "$tool"; else warn "$tool not found on PATH (open a new shell and check again)"; missing=1; fi
  done
  [ "$missing" = 0 ] && say "All four tools are installed."
fi

say 'Done. Next: in each repo you push from, run `no-mistakes init` once.'
