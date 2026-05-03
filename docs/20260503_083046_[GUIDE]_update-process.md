# [GUIDE] Update process — propagating changes from rl3-templates to consumers

| Field | Value |
|---|---|
| Status | current |
| Audience | rl3-templates maintainers + consumer-repo developers |
| Companion doc | `[GUIDE] hooks-and-policy-reference.md` (the canonical hook reference) |

This document explains how a change to `rl3-templates` flows into every consumer repository. Read top to bottom — each section is one phase of the lifecycle.

## 1. The lifecycle in one diagram

```mermaid
flowchart LR
  A[Author edits<br/>rl3-templates] --> B[PR feature → develop]
  B --> C[PR develop → master]
  C --> D[Tag v0.X.Y on master]
  D --> E[Weekly cron in each consumer<br/>.github/workflows/template-drift.yml]
  E --> F[copier update]
  F --> G[Auto-PR on consumer:<br/>chore(template): sync rl3-templates baseline]
  G --> H[Consumer dev<br/>reviews + merges]
  H --> I[Consumer up-to-date]
```

## 2. Author flow — changing `rl3-templates`

### 2.1 Branch + edit

```bash
cd ~/projects/rl3-templates
git fetch origin develop
git switch -c feature/<git-username>/<slug> origin/develop
# edit baseline/.pre-commit-config.yaml.jinja, scripts/hooks/*, etc.
```

Edit the relevant file in `baseline/`. The most common edit targets:

| File | What it controls |
|---|---|
| `baseline/.pre-commit-config.yaml.jinja` | The 7 hook blocks |
| `baseline/.claude/settings.json.jinja` | Agent deny / allow + PreToolUse / PostToolUse |
| `baseline/scripts/hooks/*.sh` | The hook script logic |
| `baseline/CLAUDE.md.jinja` | Agent contract text |
| `copier.yml` | Prompts + `_tasks` |

Do NOT edit content between `# rl3-templates: managed BEGIN` / `END` markers in consumer repos — those are auto-replaced.

### 2.2 Validate locally

```bash
bash tests/validate.sh
```

Must show `97 / 97 PASS` (or higher if new tests). Any regression blocks the PR.

### 2.3 PR + merge cycle

```bash
git push -u origin feature/<git-username>/<slug>
gh pr create --base develop --title "..." --body "..."
# wait for ci.yml to pass: shellcheck, actionlint, jinja-syntax, validate
# merge feature → develop (squash)
gh pr create --base master --head develop --title "release: vX.Y.Z"
# merge develop → master (squash)
```

### 2.4 Tag the release

After `develop → master` merges:

```bash
git fetch origin master
git tag -a vX.Y.Z origin/master -m "rl3-templates vX.Y.Z — <one-line summary>"
git push origin vX.Y.Z
```

Versioning:

| Change | Bump |
|---|---|
| Hook bug fix, doc clarification, no consumer-visible behavior change | patch — `v0.2.X` |
| New Copier flag with default that preserves existing behavior, new optional hook | minor — `v0.X.0` |
| Breaking change (renamed flag, removed hook, restructured `.copier-answers.yml`) | major — `v1.X.0` |

## 3. Consumer sync flow — automatic

Every consumer repo has `.github/workflows/template-drift.yml` rendered into it. The workflow runs on a weekly cron:

```yaml
on:
  schedule:
    - cron: "0 9 * * 1"   # Mondays 09:00 UTC
  workflow_dispatch: {}
```

Each Monday the cron:

1. Checks out the consumer repo.
2. Installs Copier via pipx.
3. Runs:
   ```bash
   copier update --defaults --conflict rej --skip-answered
   ```
4. If `git status --porcelain` shows changes, opens a PR titled `chore(template): sync rl3-templates baseline` on branch `chore/rl3-templates-bot/sync` targeting `develop`.
5. PR body lists conflicts (if any).

Consumer dev reviews the auto-PR, resolves any `.rej` files, merges.

### 3.1 Auth for cross-repo template fetch

The cron uses `secrets.RL3_TEMPLATES_PULL_TOKEN || secrets.GITHUB_TOKEN`. If `rl3-templates` is in the same org as the consumer, the default `GITHUB_TOKEN` works. Otherwise add a fine-grained PAT named `RL3_TEMPLATES_PULL_TOKEN` with `contents: read` on `rl3aiboutique-cpu/rl3-templates`.

## 4. Consumer sync flow — manual

Any time, in any consumer:

```bash
copier update --skip-answered
```

Useful when:

- A bug fix lands in rl3-templates and you don't want to wait until Monday.
- The cron is disabled in this repo.
- You're testing a pre-release tag with `--vcs-ref vX.Y.Z-rc1`.

## 5. What gets overwritten vs preserved

| Section | Behavior on `copier update` |
|---|---|
| Files between `# rl3-templates: managed BEGIN` / `END` markers | replaced |
| Files with `<!-- rl3-templates: managed BEGIN -->` / `END` (CLAUDE.md) | replaced |
| `.copier-answers.yml` | refreshed — the `_commit` pin updates to the new template version |
| Hook scripts under `scripts/hooks/` | replaced — they are static template assets |
| Files outside markers (e.g. `## Project-specific notes` in CLAUDE.md) | preserved |
| Files added by the consumer that don't exist in the template | preserved (Copier won't delete files) |

### 5.1 The managed-content marker pattern

Every templated file that mixes managed + free-form content uses delimited markers. To preserve consumer customizations, place them OUTSIDE the markers.

Example — `CLAUDE.md`:

```markdown
# CLAUDE.md — my-project

<!-- rl3-templates: managed BEGIN -->

## Branching policy
<...full template content...>

<!-- rl3-templates: managed END -->

## Project-specific notes

<consumer adds custom content here — survives every copier update>
```

If the consumer hand-edits content INSIDE the markers, `copier update` writes the conflict as a `.rej` file. The consumer's edits are still on disk in the repo (in the original committed file), but the new template version is in `.rej` for them to merge.

## 6. Conflict handling — `.rej` files

When `copier update` detects that the consumer hand-edited managed content AND the template version of the same file changed:

```
.pre-commit-config.yaml         <- consumer's version, kept
.pre-commit-config.yaml.rej     <- new template version, for review
```

The auto-PR description will say `Conflicts: YES — see .rej files`. Resolution:

```bash
git diff .pre-commit-config.yaml .pre-commit-config.yaml.rej
# decide line by line which side wins
# typical: take the new template + re-apply your edits OUTSIDE the managed markers
rm .pre-commit-config.yaml.rej
git add .pre-commit-config.yaml && git commit
```

If conflicts are extensive, the auto-PR is opened as a **draft**. Convert to ready-for-review only after resolution.

## 7. Pinning a consumer to a specific version

To freeze a consumer at the current template version (won't update on cron):

Edit `.copier-answers.yml`:

```yaml
_commit: v0.2.0          # was: an auto-bumped tag
```

…and disable the cron in `.github/workflows/template-drift.yml` (set `workflow_dispatch: {}` only, drop the `schedule:` block) or remove the workflow entirely.

To unpin later, delete the workflow modifications and run `copier update`.

## 8. Reverting a sync

If an auto-sync PR introduced a regression that you only spot post-merge:

```bash
git revert <merge-sha>
git push origin develop
```

This reverts the merged commit. Then the next Monday's cron will try to apply the same update again — to prevent that, EITHER:

- Pin `_commit:` to the version BEFORE the bad sync (option 7)
- Wait for rl3-templates to ship the fix and let the next sync pick up the corrected version

## 9. Trying a pre-release in one consumer first

Before tagging `vX.Y.Z` on master, validate against a real consumer:

```bash
# in rl3-templates
git tag vX.Y.Z-rc1 feature/<branch>
git push origin vX.Y.Z-rc1

# in any consumer
git switch -c chore/<git-username>/test-template-rc origin/develop
copier update --vcs-ref vX.Y.Z-rc1
git status                       # inspect the diff
git push -u origin chore/<git-username>/test-template-rc
gh pr create --base develop --title "test: rl3-templates vX.Y.Z-rc1"
```

Iterate on rc tags until the consumer renders cleanly. Then drop the rc tag and create the real `vX.Y.Z` from master.

## 10. Update cadence — recommendations

| Change type | Author cadence | Consumer expectation |
|---|---|---|
| Critical security fix (gitleaks rule, secret-scan addition) | tag immediately, post in #engineering | merge auto-PR within 24h |
| Hook bug fix or false-positive resolution | weekly batch | merge auto-PR same week |
| New optional flag, doc improvement | monthly batch | review on next sync |
| Breaking change (major bump) | quarterly | coordinated migration window with team |

## 11. Common operations cheatsheet

| Task | Command |
|---|---|
| Edit template, ship a fix | `git switch -c feature/<user>/<slug> origin/develop` → edit → `bash tests/validate.sh` → push → PR develop → PR master → tag |
| Force a consumer to sync now | `cd <consumer> && copier update --skip-answered` |
| See which template version a consumer is pinned at | `grep _commit .copier-answers.yml` |
| Skip the next auto-sync in one consumer | comment out `schedule:` in `.github/workflows/template-drift.yml` |
| Roll back a bad sync | `git revert <merge-sha>` + pin `_commit:` to last known good |
| Render-test a consumer locally without committing | `cp -r <consumer> /tmp/test && cd /tmp/test && copier update --pretend` |
| Dry-run the next sync to see the diff | `copier update --pretend --skip-answered` |

## 12. When rl3-templates itself needs updating from a downstream learning

If a consumer team discovers a useful pattern (e.g. a missing hook, a tighter rule), the upstream-flow is:

1. Consumer team opens an issue in `rl3aiboutique-cpu/rl3-templates` describing the pattern.
2. Maintainer (`@lehidalgo` or `@novasvilla`) reviews.
3. Maintainer authors the change per §2 above. Consumer-team can also open a PR directly.
4. After merge + tag, the auto-sync brings it to every consumer (including the one that requested it).

Do NOT cherry-pick template changes into individual consumers without first landing them upstream — that's how baselines drift.
