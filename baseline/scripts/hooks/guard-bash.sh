#!/usr/bin/env bash
# scripts/hooks/guard-bash.sh
#
# Claude Code PreToolUse filter for the Bash tool.
# Reads JSON on stdin, decides allow / block.
#
# Exit semantics:
#   0   allow — any stdout/stderr is informational
#   2   block — stderr is shown to Claude as the reason
#
# This script is the single source of truth for which Bash commands the
# agent is allowed to run. The .claude/settings.json deny-list is a coarser
# first pass; this script catches edge cases (refspec parsing, push to
# protected branch via HEAD:master, etc.).

set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null || echo "")

if [ -z "$cmd" ]; then
  exit 0
fi

block() {
  echo "BLOCKED by rl3-templates guard-bash: $1" >&2
  echo "" >&2
  echo "Command: $cmd" >&2
  echo "" >&2
  echo "If this rule is wrong, edit scripts/hooks/guard-bash.sh and explain why." >&2
  exit 2
}

# ── --no-verify variants ───────────────────────────────────────────────────
if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+(commit|push|merge|rebase)([[:space:]]|$).*--no-verify'; then
  block "--no-verify is forbidden for the agent. If a hook is wrong, fix the hook."
fi

if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+commit[[:space:]]+([^|]*[[:space:]])?-n([[:space:]]|$)'; then
  block "git commit -n (alias for --no-verify) is forbidden."
fi

# ── force push ─────────────────────────────────────────────────────────────
if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+push[[:space:]]+.*--force([[:space:]]|$)'; then
  if ! echo "$cmd" | grep -qE '\-\-force-with-lease'; then
    block "git push --force is forbidden. Use --force-with-lease (refuses if remote moved)."
  fi
fi

# Match `-f` either immediately after `push ` or later as a standalone flag.
if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+push[[:space:]]+(-f|.*[[:space:]]-f)([[:space:]]|$)'; then
  block "git push -f is forbidden. Use --force-with-lease."
fi

# ── direct push to protected branches ──────────────────────────────────────
for protected in master main develop; do
  # git push <remote> <protected>
  if echo "$cmd" | grep -qE "(^|[[:space:]])git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+${protected}([[:space:]]|$)"; then
    block "Direct push to ${protected} is forbidden. Open a PR instead."
  fi
  # git push <remote> HEAD:<protected> or HEAD:refs/heads/<protected>
  if echo "$cmd" | grep -qE "(^|[[:space:]])git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+HEAD:(refs/heads/)?${protected}([[:space:]]|$)"; then
    block "Direct push to ${protected} via HEAD: refspec is forbidden. Open a PR instead."
  fi
  # git push <remote> <branch>:<protected>
  if echo "$cmd" | grep -qE "(^|[[:space:]])git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+:${protected}([[:space:]]|$)"; then
    block "Pushing any branch to ${protected} is forbidden."
  fi
  # git push <remote> refs/heads/<protected>
  if echo "$cmd" | grep -qE "(^|[[:space:]])git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+refs/heads/${protected}([[:space:]]|$)"; then
    block "Direct push to refs/heads/${protected} is forbidden."
  fi
done

# ── checkout / switch onto protected ───────────────────────────────────────
if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+(checkout|switch)[[:space:]]+(master|main|develop)([[:space:]]|$)'; then
  block "Checking out master/main/develop is forbidden for the agent. Stay on a feature branch and use 'git fetch + git merge origin/<branch>' to integrate."
fi

# ── reset / clean / restore destructive forms ──────────────────────────────
if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'; then
  block "git reset --hard is destructive. Use 'git stash' or commit a checkpoint first."
fi

if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+clean[[:space:]]+(-f|-fd|-df|-fdx|-xfd)([[:space:]]|$)'; then
  block "git clean with -f is destructive. Inspect with 'git clean -n' first."
fi

if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+(checkout|restore)[[:space:]]+\.([[:space:]]|$)'; then
  block "git checkout . / git restore . overwrites uncommitted changes. Stash or commit instead."
fi

# ── git config global ──────────────────────────────────────────────────────
if echo "$cmd" | grep -qE '(^|[[:space:]])git[[:space:]]+config[[:space:]]+--global'; then
  block "Modifying the user's global git config is forbidden."
fi

# ── package managers ───────────────────────────────────────────────────────
if echo "$cmd" | grep -qE '(^|[[:space:]])pip[[:space:]]+install([[:space:]]|$)'; then
  if ! echo "$cmd" | grep -qE 'uv[[:space:]]+pip[[:space:]]+install'; then
    block "Use 'uv add <pkg>' instead of pip install (lockfile + venv)."
  fi
fi

if echo "$cmd" | grep -qE '(^|[[:space:]])npm[[:space:]]+(install|i)([[:space:]]|$)'; then
  if ! echo "$cmd" | grep -qE '(--package-lock-only|[[:space:]]ci([[:space:]]|$))'; then
    proj="${CLAUDE_PROJECT_DIR:-.}"
    if [ ! -f "$proj/package-lock.json" ] \
       && [ ! -f "$proj/pnpm-lock.yaml" ] \
       && [ ! -f "$proj/yarn.lock" ] \
       && [ ! -f "$proj/bun.lock" ]; then
      block "npm install with no lockfile present. Use 'npm ci' or commit the lockfile first."
    fi
  fi
fi

# ── curl pipe shell ────────────────────────────────────────────────────────
if echo "$cmd" | grep -qE '(curl|wget)[[:space:]]+[^|]*\|[[:space:]]*(sh|bash|zsh)([[:space:]]|$)'; then
  block "curl|sh is a remote-execution pattern. Download to a file, inspect, then execute."
fi

# ── rm -rf at dangerous targets ────────────────────────────────────────────
# Note: the agent passes commands as raw strings (unexpanded), so we match the
# literal '$HOME' substring. shellcheck SC2016 is a false positive here.
# shellcheck disable=SC2016
if echo "$cmd" | grep -qE '(^|[[:space:]])rm[[:space:]]+(-rf|-r[[:space:]]+-f|-fr)[[:space:]]+(/|~|\$HOME)([[:space:]]|$)'; then
  block "rm -rf at root or home is forbidden."
fi

if echo "$cmd" | grep -qE '(^|[[:space:]])rm[[:space:]]+(-rf|-fr)[[:space:]]+\.\.([[:space:]]|/|$)'; then
  block "rm -rf at parent directory is forbidden."
fi

# ── chmod -R / chown -R on broad targets ───────────────────────────────────
# shellcheck disable=SC2016
if echo "$cmd" | grep -qE '(^|[[:space:]])(chmod|chown)[[:space:]]+-R[[:space:]]+[^[:space:]]+[[:space:]]+(/|~|\$HOME)([[:space:]]|$)'; then
  block "Recursive chmod/chown on root or home is forbidden."
fi

# All checks passed
exit 0
