#!/usr/bin/env bash
# migrate-ignore-files.sh — one-time migration helper for rl3-templates v0.2.4.
#
# Use case: a consumer project upgrading from a pre-v0.2.4 template version
# (which shipped no .gitignore / .dockerignore) to v0.2.4+ (which ships both
# with managed BEGIN/END marker blocks). On first `copier update`, copier
# overwrites the existing .gitignore with the new managed block, dropping any
# project-specific rules the consumer had added. This script recovers those
# rules from `git show HEAD:.gitignore` and appends them below the END marker.
#
# Run order:
#   1. git fetch && git checkout -b chore/<user>/v0.2.4-update develop
#   2. copier update --skip-answered --trust
#   3. bash scripts/migrate-ignore-files.sh        ← this script
#   4. Review diff. Commit. Open PR.
#
# Idempotency: the script checks for the BEGIN marker. If it sees that
# project-specific rules are already preserved, it exits without changes.
#
# Exit codes:
#   0 — migration succeeded or no-op (idempotent re-run).
#   1 — pre-condition failed (not a git repo, marker missing, etc.).

set -uo pipefail

MARKER_BEGIN="# rl3-templates: managed BEGIN"
MARKER_END="# rl3-templates: managed END"

log()  { printf '[migrate-ignore-files] %s\n' "$*"; }
warn() { printf '[migrate-ignore-files] WARN: %s\n' "$*" >&2; }
fail() { printf '[migrate-ignore-files] ERROR: %s\n' "$*" >&2; exit 1; }

# ── Pre-conditions ─────────────────────────────────────────────────────────
git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not a git repo"
cd "$(git rev-parse --show-toplevel)"

# ── Per-file migration ─────────────────────────────────────────────────────
migrate_file() {
  local file="$1"
  local label="$2"

  if [ ! -f "$file" ]; then
    log "$label: $file does not exist (likely gated off in copier answers); skipping."
    return 0
  fi

  if ! grep -qF "$MARKER_BEGIN" "$file"; then
    fail "$file lacks the BEGIN marker. Did you run \`copier update\` first? See header."
  fi

  # Recover the pre-update version from git HEAD.
  local recovered
  recovered="$(mktemp)"
  if git show "HEAD:$file" >"$recovered" 2>/dev/null; then
    : # Recovered.
  else
    log "$label: $file did not exist at HEAD; nothing to merge."
    rm -f "$recovered"
    return 0
  fi

  # Empty recovered file → nothing to merge.
  if [ ! -s "$recovered" ]; then
    log "$label: HEAD:$file is empty; nothing to merge."
    rm -f "$recovered"
    return 0
  fi

  # Build the set of lines already present in the new file (entire content).
  # We deduplicate against the FULL file, not just the managed block, so that
  # rules already moved below END marker by a previous run aren't re-added.
  local present
  present="$(mktemp)"
  awk 'NF && $0 !~ /^[[:space:]]*#/' "$file" | sort -u >"$present"

  # Filter recovered file: keep only non-blank, non-comment lines that are
  # NOT already in the new file.
  local new_rules
  new_rules="$(mktemp)"
  awk 'NF && $0 !~ /^[[:space:]]*#/' "$recovered" | sort -u | comm -23 - "$present" >"$new_rules"

  if [ ! -s "$new_rules" ]; then
    log "$label: no project-specific rules to preserve."
    rm -f "$recovered" "$present" "$new_rules"
    return 0
  fi

  # Append the new rules below the END marker, with a section header.
  local count
  count="$(wc -l < "$new_rules" | tr -d ' ')"
  log "$label: appending $count project-specific rule(s) below END marker."

  {
    echo ""
    echo "# ── Recovered from pre-v0.2.4 $file (migrated $(date -u +'%Y-%m-%d')) ──"
    cat "$new_rules"
  } >>"$file"

  rm -f "$recovered" "$present" "$new_rules"
  log "$label: migration applied to $file."
}

# ── Run ────────────────────────────────────────────────────────────────────
migrate_file ".gitignore"     "gitignore"
migrate_file ".dockerignore"  "dockerignore"

log "Done. Review the diff:"
log "  git diff -- .gitignore .dockerignore"
log "Then stage, commit, and open the upgrade PR."
