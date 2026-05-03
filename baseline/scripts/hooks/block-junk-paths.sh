#!/usr/bin/env bash
# block-junk-paths.sh — pre-commit hook that fails when staged files match a
# blocklist of paths that should never be tracked in git.
#
# Why: even with a correct .gitignore, accidental tracking can happen via
# `git add -A` after a botched merge, a broken .gitignore, or a force-add.
# This hook is the load-bearing fail-loud guard. It reads `git diff --cached`
# directly and refuses to let the commit proceed if any staged path matches.
#
# Bypass (use sparingly, audit later): RL3_ALLOW_JUNK_PATHS=1 git commit ...
#
# Exit codes:
#   0  — no staged files match the blocklist (or bypass set).
#   1  — blocklist match found; commit refused.

set -uo pipefail

if [ "${RL3_ALLOW_JUNK_PATHS:-0}" = "1" ]; then
  echo "block-junk-paths: bypass active (RL3_ALLOW_JUNK_PATHS=1)" >&2
  exit 0
fi

# Patterns matched against staged file paths. Each line is a POSIX extended
# regex anchored with implicit `^...$` semantics via grep -E.
PATTERNS=(
  # ── Node / pnpm / yarn install artefacts ───────────────────────────────
  '(^|/)node_modules/'
  '(^|/)\.pnpm-store/'
  '(^|/)\.yarn/(cache|unplugged|build-state\.yml|install-state\.gz)'

  # ── JS/TS build output ─────────────────────────────────────────────────
  '(^|/)dist/'
  '(^|/)build/'
  '(^|/)out/'
  '(^|/)\.next/'
  '(^|/)\.nuxt/'
  '(^|/)\.svelte-kit/'
  '(^|/)\.turbo/'
  '(^|/)\.parcel-cache/'
  '(^|/)\.tanstack/'

  # ── Python install / bytecode / caches ─────────────────────────────────
  '(^|/)\.venv/'
  '(^|/)venv/'
  '(^|/)__pycache__/'
  '\.py[cod]$'
  '(^|/)\.ruff_cache/'
  '(^|/)\.mypy_cache/'
  '(^|/)\.pytest_cache/'
  '(^|/)\.tox/'
  '(^|/)\.nox/'
  '(^|/)\.hypothesis/'
  '(^|/)htmlcov/'
  '(^|/)\.coverage(\.|$)'

  # ── Terraform state ────────────────────────────────────────────────────
  '(^|/)\.terraform/'
  '\.tfstate$'
  '\.tfstate\.backup$'

  # ── OS junk ────────────────────────────────────────────────────────────
  '(^|/)\.DS_Store$'
  '(^|/)Thumbs\.db$'
  '(^|/)Desktop\.ini$'

  # ── Logs ───────────────────────────────────────────────────────────────
  '\.log$'

  # ── Editor swap ────────────────────────────────────────────────────────
  '\.sw[opqr]$'

  # ── Docker volume mounts ───────────────────────────────────────────────
  '(^|/)pgdata/'
  '(^|/)mysqldata/'
  '(^|/)mongodata/'
  '(^|/)redisdata/'
)

# Allowlist for known false positives. Each entry is checked against the path
# AFTER pattern match — if any allow-pattern matches, the file is NOT blocked.
ALLOW_PATTERNS=(
  # CHANGELOG.md mentions "*.log" patterns when documenting rules.
  '(^|/)CHANGELOG\.md$'
  # docs/ references blocklist patterns when describing the rule itself.
  '^docs/.*\.md$'
  # Test fixtures may legitimately need to exercise these patterns.
  '^tests/fixtures/'
)

# Read staged file list. Empty on rebases, merges with no changes, etc.
mapfile -t STAGED < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
[ "${#STAGED[@]}" -eq 0 ] && exit 0

VIOLATIONS=()
for path in "${STAGED[@]}"; do
  matched=""
  for pat in "${PATTERNS[@]}"; do
    if echo "$path" | grep -qE "$pat"; then
      matched="$pat"
      break
    fi
  done
  [ -z "$matched" ] && continue

  # Allowlist check.
  allowed=""
  for ap in "${ALLOW_PATTERNS[@]}"; do
    if echo "$path" | grep -qE "$ap"; then
      allowed="1"
      break
    fi
  done
  [ -n "$allowed" ] && continue

  VIOLATIONS+=("$path  (matched: $matched)")
done

if [ "${#VIOLATIONS[@]}" -gt 0 ]; then
  cat >&2 <<EOF

✗ block-junk-paths: ${#VIOLATIONS[@]} staged path(s) match the blocklist.

These paths must not be tracked in git. They are typically install artefacts,
build output, caches, or local state that .gitignore should be excluding.

Offending paths:
EOF
  for v in "${VIOLATIONS[@]}"; do
    printf '  %s\n' "$v" >&2
  done
  cat >&2 <<EOF

Remediation:
  1. Unstage:  git restore --staged <path>...
  2. Verify .gitignore covers the pattern (run \`copier update\` if the managed
     block is missing or stale — see baseline/.gitignore.jinja).
  3. If the path is legitimately needed in this repo, add an exception below
     the # rl3-templates: managed END marker in .gitignore, or extend
     ALLOW_PATTERNS in scripts/hooks/block-junk-paths.sh via a PR to rl3-templates.

Bypass (audited): RL3_ALLOW_JUNK_PATHS=1 git commit ...

EOF
  exit 1
fi

exit 0
