# Documentation index

One-line index of every Markdown document in this repository. Update on every doc add or status change.

| File | Status | One-line summary |
|---|---|---|
| `20260502_201709_[PLAN]_baseline-template-implementation.md` | current | Phase 1 implementation plan for the `baseline` template (standalone hooks + agent guardrails, no codi/rl3-ci coupling). |
| `20260502_213135_[GUIDE]_hooks-and-policy-reference.md` | current | **Canonical reference.** Every hook, every rule, every Copier flag, every policy — with detailed tables. Read first. |
| `20260502_212730_[REPORT]_baseline-validation.md` | current | End-to-end validation report — 91/91 tests pass on the rendered fullstack sandbox; covers all 8 hook scripts, pre-commit config, and Claude settings. |

## Conventions

- Filename format: `YYYYMMDD_HHMMSS_[CATEGORY]_<slug>.md` (closed category set; see `/Users/laht/.claude/rules/documentation.md`).
- All documentation lives in this single flat `docs/` directory. No subdirectories.
- Filter by category with `ls docs/ | grep '\[PLAN\]'`.
- Diagrams use Mermaid only — no ASCII art.
