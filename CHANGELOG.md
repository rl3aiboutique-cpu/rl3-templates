# Changelog

All notable changes to this project. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Phase 2A retrofit completion: rl3-website pending re-open after rebase (PR #77 closed with head-out-of-date).
- Phase 2B planning: `enable_rl3_ci` flag → renders thin CI caller targeting `rl3aiboutique-cpu/rl3-ci@v1`. Trigger met (3+ retrofits merged).
- Open Item O4: rl3-templates dogfooding its own hooks on itself.

## [0.2.1] — 2026-05-03

### Fixed

- **`orphan-todo` hook** — added `exclude:` for `CLAUDE.md`, `.pre-commit-config.yaml`, `docs/*_[GUIDE]_*.md`, `docs/*_[PLAN]_*.md`. Documentation that describes the rule by mentioning the literal "TODO" was tripping the hook.
- **`forbid-coauthor-claude` hook** — same exclusion pattern. `CLAUDE.md` mentions the forbidden trailer when documenting the rule.
- **`forbid-edits-to-generated` hook** — dropped `.copier-answers.yml` from the `files:` pattern. The file is created on the bootstrap commit and refreshed on every `copier update`; Layer-B `guard-write.sh` is the right gate for agent edits.
- **`yamllint`** — bumped `empty-lines.max` from 2 to 10. Jinja conditionals in `.pre-commit-config.yaml.jinja` collapse to ~6 consecutive blanks; bumping leaves headroom.
- **`typos`** — removed `mis-match`, `quater`, `nd` from `.codespellrc` ignore-list. typos does not read codespell config and was flagging them as real typos.

### Added

- `docs/[GUIDE]_update-process.md` — 12-section reference for how rl3-templates changes propagate to every consumer repo: author flow, weekly cron sync, manual sync, conflict handling (.rej files), pinning, rollback, pre-release validation.

### Verified

- `tests/validate.sh`: 97 / 97 PASS (unchanged from v0.2.0).
- Fresh fullstack render + `pre-commit run --all-files`: clean exit on every hook.

## [0.2.0] — 2026-05-02

### Added

- `enable_branch_policy: bool` Copier flag for lib mode (small libraries, single-branch repos like `rl3-ci`). When `false`, skips branch-naming / no-direct-push / branch-source-base hooks; trims `no-commit-to-branch` to production branch only; trims Claude deny-list of integration-branch entries; CLAUDE.md uses LIGHTWEIGHT branching section.
- `.github/workflows/ci.yml` — rl3-templates self-CI with 4 jobs: shellcheck, actionlint, jinja-syntax, validate. Standalone (no rl3-ci coupling).
- 6 new lib-shape tests in `tests/validate.sh` (now 97 / 97).
- `docs/[GUIDE]_hooks-and-policy-reference.md` — canonical 534-line reference: every hook, every rule, every Copier flag, every policy.
- `docs/[REPORT]_baseline-validation.md` — first archived validation run.

### Changed

- `tests/validate.sh` — `TPL` auto-detected from script location (was hardcoded). Overridable via `RL3_TEMPLATES_REPO` env (used by ci.yml).

## [0.1.0] — 2026-05-02

### Added

- 8 standalone hook scripts under `baseline/scripts/hooks/` — Claude PreToolUse / PostToolUse + pre-push branch policy.
- 7-block pre-commit config: hygiene, secrets, anti-slop, python, ts, infra, commit-msg + pre-push tier.
- Claude Code permissions: 32–37 deny / 1–15 allow + Pre/PostToolUse hooks.
- 17-file `baseline/` Copier template + idempotent `_tasks` for `pre-commit install`.
- Weekly `template-drift.yml` workflow rendered into every consumer.
- CODEOWNERS at the rl3-templates repo root: `@lehidalgo` + `@novasvilla`.
- `docs/[PLAN]_baseline-template-implementation.md` — Phase 1 implementation plan.

### Architecture

- Three layers: Claude PreToolUse (Layer B), pre-commit framework (Layer A), CI (Layer C, deferred to Phase 2B).
- Copier 9.x with `_subdirectory: "baseline"`, `_templates_suffix: ".jinja"`, managed-content markers for in-place updates.
- Standalone — no codi or rl3-ci coupling. Both planned as opt-in flags in later phases.

[Unreleased]: https://github.com/rl3aiboutique-cpu/rl3-templates/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/rl3aiboutique-cpu/rl3-templates/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/rl3aiboutique-cpu/rl3-templates/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rl3aiboutique-cpu/rl3-templates/releases/tag/v0.1.0
