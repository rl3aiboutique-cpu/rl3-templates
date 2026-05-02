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

This repository follows the same policy it ships.

**Branch shape:** `<prefix>/<git-username>/<slug>` (with optional `<TICKET-ID>-` infix in the slug).

| Prefix | Branched from | PR target | Use case |
|---|---|---|---|
| `feature/` | `develop` | `develop` | New feature |
| `bugfix/` | `develop` | `develop` | Non-urgent bug fix |
| `chore/` | `develop` | `develop` | Tooling, deps, docs |
| `release/` | `develop` | `master` | Release PR |
| `hotfix/` | `master` | `master` (then `develop`) | Production fix + back-merge |

Examples:

- `feature/lehidalgo/add-csv-export`
- `feature/lehidalgo/RL3-142-add-csv-export`
- `hotfix/jdoe/CBP-99-fix-payment`
- `chore/lehidalgo/bump-deps`

The `<git-username>` segment comes from `git config user.name`, normalised to lowercase kebab-case. It enforces ownership and avoids name collisions across contributors.

No direct push to `master` or `develop`. No `--no-verify` for the agent.

## License

MIT — see `LICENSE`.
