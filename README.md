# rl3-templates

Project templates for RL3 AI Agency repositories. Built on [Copier](https://copier.readthedocs.io/) for idempotent rendering and 3-way merge updates.

## Status

**Phase 1 — in progress.** Authoring the `baseline` template that ships local hooks (pre-commit, commit-msg, pre-push) and Claude Code agent guardrails.

Phase 1 is intentionally **standalone**:
- No coupling to [`codi`](https://github.com/lehidalgo/codi).
- No coupling to [`rl3-ci`](https://github.com/rl3aiboutique-cpu/rl3-ci) reusable workflows.

Both are planned as opt-in flags in later phases — see `docs/` for the canonical [PLAN] document.

## Goal

Every new RL3 repository starts with the same hooks, branch policy, and agent guardrails through one command:

```bash
copier copy gh:rl3aiboutique-cpu/rl3-templates --src baseline ./my-new-repo
```

After day 0, template changes propagate to existing repos via a weekly drift PR (`copier update`).

## Repository layout

```
rl3-templates/
├── README.md                                ← this file
├── LICENSE                                  ← MIT
├── docs/
│   ├── _index.md                            ← doc index
│   └── YYYYMMDD_HHMMSS_[PLAN]_*.md          ← implementation plan
└── baseline/                                ← (Phase 1) the only template
    ├── copier.yml                           ← prompts + tasks
    └── {{ project_slug }}/                  ← rendered into target repo
        ├── .pre-commit-config.yaml.j2
        ├── .claude/settings.json.j2
        ├── .github/workflows/template-drift.yml
        ├── scripts/hooks/                   ← standalone hook scripts
        └── ...
```

## Branching policy

This repository follows the same policy it ships:

- `master` — production. Receives PRs from `develop`, `release/*`, `hotfix/*`.
- `develop` — integration. Receives PRs from `feature/*`, `bugfix/*`, `chore/*`, `hotfix/*`.
- `feature/*`, `bugfix/*`, `chore/*` — branched from `develop`.
- `hotfix/*` — branched from `master`. Mandatory back-merge to `develop`.

No direct push to `master` or `develop`. No `--no-verify` for the agent.

## License

MIT — see `LICENSE`.
