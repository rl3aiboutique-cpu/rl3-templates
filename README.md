# rl3-templates

Project templates for RL3 AI Agency repositories. Built on [Copier](https://copier.readthedocs.io/) for idempotent rendering and 3-way merge updates.

## Status

**v0.1.0 — Phase 1 complete.** The `baseline` template ships:

- Local pre-commit hooks (commit, commit-msg, pre-push tiers).
- Claude Code agent guardrails (`.claude/settings.json` deny/allow + PreToolUse / PostToolUse hooks).
- Branch policy enforcement (`<prefix>/<git-username>/<slug>` shape; refuse direct push to `master` / `develop`).
- Anti-slop hooks (700-line cap, orphan-TODO blocker, NotImplementedError blocker, Co-Authored-By Claude scanner).
- MCP / agent-config secret scanner (Sandworm-mode mitigation, Feb 2026).
- Weekly drift-detection workflow (`copier update` PR every Monday).

Phase 1 is intentionally **standalone** — no `codi` or `rl3-ci` coupling. Both are planned as opt-in flags in later phases:

| Phase | Adds | Trigger |
|---|---|---|
| 1 | Hooks + agent guardrails (this release) | Done — `v0.1.0` |
| 2 | `enable_rl3_ci` flag → renders thin CI caller targeting `rl3-ci@v1` | After 3+ consumer-repo retrofits |
| 3 | `enable_codi` flag → renders `.codi/` skeleton + skill tracker / observer | After Phase 2 stable |

## Quick start (consumer repo)

```bash
# New repo
copier copy gh:rl3aiboutique-cpu/rl3-templates ./my-new-repo
cd my-new-repo
git init && git add -A && git commit -m "chore: initial commit from rl3-templates"

# Refresh existing repo from the template
copier update --skip-answered
```

After the initial render, the `_tasks` runs `chmod +x scripts/hooks/*.sh` and (if `git init` has run + `pre-commit` is on PATH) `pre-commit install` for commit / commit-msg / pre-push.

## Documentation

| File | What's in it |
|---|---|
| `docs/<timestamp>_[GUIDE]_hooks-and-policy-reference.md` | **Read first.** Detailed reference: every hook, every rule, every flag, with tables. |
| `docs/<timestamp>_[PLAN]_baseline-template-implementation.md` | Phase-1 implementation plan (history of what was built and why). |
| `docs/<timestamp>_[REPORT]_baseline-validation.md` | Latest validation suite results — 91 / 91 PASS at v0.1.0. |

The full doc index is in `docs/_index.md`.

## Repository layout

```
rl3-templates/
├── README.md                                  ← this file
├── LICENSE                                    ← MIT
├── copier.yml                                 ← root config, _subdirectory: "baseline"
├── docs/
│   ├── _index.md                              ← doc index
│   ├── *_[PLAN]_*.md                          ← implementation plans
│   ├── *_[GUIDE]_*.md                         ← hooks + policy reference
│   └── *_[REPORT]_*.md                        ← validation reports
├── tests/
│   ├── README.md                              ← how to run the suite
│   └── validate.sh                            ← end-to-end validation harness
└── baseline/                                  ← what Copier renders into a consumer
    ├── .pre-commit-config.yaml.jinja          ← 7 blocks, conditionally rendered
    ├── .claude/settings.json.jinja            ← deny / allow + Pre/PostToolUse hooks
    ├── .copier-answers.yml.jinja              ← persists answers for `copier update`
    ├── CLAUDE.md.jinja                        ← agent contract with managed markers
    ├── .gitleaks.toml
    ├── .yamllint.yaml
    ├── .codespellrc
    ├── .github/workflows/template-drift.yml   ← weekly auto-PR
    └── scripts/
        ├── setup-branch-protection.sh         ← idempotent gh api configurator
        └── hooks/                             ← 8 standalone scripts
            ├── guard-bash.sh                  ← PreToolUse Bash filter (12 rules)
            ├── guard-write.sh                 ← PreToolUse Edit / Write filter
            ├── auto-format.sh                 ← PostToolUse formatter dispatcher
            ├── scan-agent-configs.sh          ← MCP secret scanner
            ├── check-branch-name.sh           ← pre-push: <prefix>/<user>/<slug>
            ├── no-direct-push.sh              ← pre-push: refuse master / develop
            ├── check-branch-base.sh           ← pre-push: branch source check
            └── check_file_lines.py            ← anti-slop: 700-line cap
```

## Branching policy (this repo + every consumer)

**Branch shape:** `<prefix>/<git-username>/<slug>`, with optional `<TICKET-ID>-` infix in the slug.

| Prefix | Branched from | PR target | Reviewers | Use case |
|---|---|---|---|---|
| `feature/` | `develop` | `develop` | 1 | New feature |
| `bugfix/` | `develop` | `develop` | 1 | Non-urgent bug fix |
| `chore/` | `develop` | `develop` | 1 | Tooling, deps, docs |
| `release/` | `develop` | `master` | 2 | Release PR |
| `hotfix/` | `master` | `master` (then `develop`) | 1 (fast) | Production fix + back-merge |

Examples:

- `feature/lehidalgo/add-csv-export`
- `feature/lehidalgo/RL3-142-add-csv-export`
- `hotfix/jdoe/CBP-99-fix-payment`
- `chore/lehidalgo/bump-deps`

The `<git-username>` segment comes from `git config user.name`, normalised to lowercase kebab. It enforces ownership and avoids collisions across contributors.

**No direct push to `master` or `develop`. No `--no-verify` for the agent. No `--force` (only `--force-with-lease`).**

The full policy — including the hotfix flow and emergency-override rules — is in the `[GUIDE]` doc, §5.

## Validation

Run the full suite locally:

```bash
bash tests/validate.sh
cat /tmp/rl3-validation/STATUS.md
```

91 tests across 9 categories. The latest archived run is in `docs/<timestamp>_[REPORT]_baseline-validation.md`.

## Contributing

This repo follows its own policy. Open work happens on `feature/<your-name>/<slug>` branches off `develop`. PRs from `develop` to `master` are the integration cadence.

## License

MIT — see `LICENSE`.
