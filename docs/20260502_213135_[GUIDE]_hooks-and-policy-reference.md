# [GUIDE] rl3-templates baseline — hooks and policy reference

| Field | Value |
|---|---|
| Status | current — Phase 1 / v0.1.0 |
| Audience | Engineers and AI coding agents working in any RL3 repository |
| Source of truth | This document. Per-repo `CLAUDE.md` is a summary; this is the full reference. |
| Updated | 2026-05-02 |

This guide documents every hook, rule, configuration knob, and policy that the `baseline` template installs into a consumer repository. Each section is self-contained — read top to bottom, or jump to the hook you care about.

## 1. Three-layer architecture

Hooks operate at three independent layers. The same logical check (for example "no secrets") fires at multiple layers — each subsequent layer is the safety net for the previous.

```
                        ┌────────────────────────────────────┐
                        │              THREAT                │
                        └────────────────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
  LAYER B (CLAUDE)          LAYER A (PRE-COMMIT)        LAYER C (CI)
  .claude/settings.json     .pre-commit-config.yaml     .github/workflows/
  scripts/hooks/guard-*.sh  scripts/hooks/*.sh          (Phase 2 — rl3-ci)
        │                          │                          │
        ▼                          ▼                          ▼
  prevents the agent        catches what the agent     authoritative gate;
  from issuing the          does manage to write       cannot be bypassed
  command at all            or stage                   by --no-verify
```

Layer B fires in seconds, before pre-commit even runs. Layer A is the deterministic local gate — survives even when the agent isn't involved. Layer C (Phase 2) is the server-side authority — `--no-verify` from any user is moot once the PR opens.

## 2. Hook scripts

The eight hook scripts live in `scripts/hooks/`. They are standalone — no codi, no rl3-ci, no Node — only `bash`, `python3`, `git`, and standard CLI tools (`grep`, `awk`, `sed`, `find`).

### 2.1 `guard-bash.sh` — PreToolUse Bash filter

| Field | Value |
|---|---|
| Layer | B (Claude Code) |
| Wired in | `.claude/settings.json` → `hooks.PreToolUse[matcher="Bash"]` |
| Trigger | Any Bash tool invocation by the agent |
| Input | JSON via stdin: `{ "tool_name": "Bash", "tool_input": { "command": "..." } }` |
| Output on allow | exit 0, no stdout/stderr |
| Output on block | exit 2, stderr explains the rule (Claude shows it as the refusal reason) |
| Test coverage | 33 cases (7 allow + 26 block) — see `[REPORT]` |
| Configuration | Edit the script directly. Each rule is a `grep -qE` pattern. |
| Bypass | None for the agent. Project-level `.claude/settings.json` `allow:` list can carve exceptions. |

#### Rules enforced (block on match)

| # | Rule class | Matches | Reason |
|---|---|---|---|
| 1 | `--no-verify` on commit/push/merge/rebase | `git (commit\|push\|merge\|rebase) ... --no-verify` | If a hook is wrong, fix the hook, not the bypass. |
| 2 | `git commit -n` short flag | `git commit -n` | Alias for `--no-verify`. |
| 3 | `git push --force` without `--force-with-lease` | `git push ... --force` (no `-with-lease`) | `--force-with-lease` refuses if the remote moved; safer. |
| 4 | `git push -f` short flag | `git push -f ...` | Same reason. |
| 5 | Direct push to protected branch | `git push <remote> <master\|main\|develop>`, plus `HEAD:`, `<branch>:`, and `refs/heads/` refspec variants | Protected branches receive changes via PR only. |
| 6 | Checkout/switch onto protected branch | `git (checkout\|switch) <master\|main\|develop>` | Stay on a feature branch and use `git fetch + git merge origin/<branch>` to integrate. |
| 7 | `git reset --hard` | Any form | Destructive. Use `git stash` or commit a checkpoint first. |
| 8 | `git clean -f` / `-fd` / `-df` / `-fdx` / `-xfd` | Force forms only | Destructive. Inspect with `git clean -n` first. |
| 9 | `git checkout .` / `git restore .` | Whole-tree restore | Overwrites uncommitted changes. |
| 10 | `git config --global` | Any modification | The user's global git config is off-limits to the agent. |
| 11 | `pip install` (raw) | `pip install ...` (excluding `uv pip install`) | RL3 standardises on `uv add` for lockfile + venv. |
| 12 | `npm install` without lockfile | `npm install ...` (excluding `npm ci`, `--package-lock-only`) when no `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` / `bun.lock` | Forces lockfile-pinned installs. |
| 13 | `curl \| sh` / `wget \| sh` | Pipe-to-shell pattern | Remote-execution risk. Download to a file, inspect, then execute. |
| 14 | `rm -rf /` / `~` / `$HOME` / `..` | Catastrophic targets | Self-explanatory. |
| 15 | `chmod -R` / `chown -R` on `/` / `~` / `$HOME` | Recursive permission change at root or home | Self-explanatory. |

Allowed counterparts (the agent CAN do these):

| Allowed | Why |
|---|---|
| `git push --force-with-lease origin <feature\|bugfix\|chore\|release\|hotfix>/*` | Safe force-push for collaboration on a feature branch. |
| `git checkout -b <prefix>/*` / `git switch -c <prefix>/*` | Creating a new feature/bugfix/etc branch is the canonical workflow. |
| `uv add <pkg>`, `uv pip install ...`, `uv tool install ...` | The RL3 Python package manager. |
| `npm ci`, `pnpm install`, `pnpm add ...`, `yarn install`, `bun install` | Lockfile-respecting installs. |
| `rm -rf /tmp/...`, `rm -rf <subdir>` | Bounded targets. |

### 2.2 `guard-write.sh` — PreToolUse Edit/Write filter

| Field | Value |
|---|---|
| Layer | B (Claude Code) |
| Wired in | `.claude/settings.json` → `hooks.PreToolUse[matcher="Edit\|Write\|NotebookEdit"]` |
| Trigger | Any Edit, Write, or NotebookEdit tool call |
| Input | JSON via stdin: `{ "tool_input": { "file_path": "..." } }` |
| Output on allow | exit 0 (silent or with a one-line WARN to stderr) |
| Output on block | exit 2, stderr names the path and the reason |
| Test coverage | 18 cases (5 allow + 13 block) |
| Configuration | Path patterns are inline `case` arms. Add an arm to introduce a new rule. |
| Bypass | None for the agent. |

#### Rules enforced

| Path pattern | Action | Reason |
|---|---|---|
| `**/routeTree.gen.ts` | block | Generated by TanStack Router. Re-run `pnpm dev` to regenerate. |
| `frontend/src/client/**` | block | Generated SDK from `@hey-api/openapi-ts`. Run `pnpm exec openapi-ts`. |
| `*_pb2.py`, `*_pb2.pyi`, `*_pb2_grpc.py` | block | Protobuf generated. Regenerate from the `.proto` source. |
| `uv.lock`, `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`, `Cargo.lock`, `poetry.lock` | block | Lockfiles are managed by the package manager. |
| `.copier-answers.yml` | block | Managed by Copier. Run `copier update` to refresh template. |
| `.env`, `.envrc` | block | Use `.env.example` for the committed template. |
| `.env.local`, `.env.development`, `.env.production`, `.env.staging`, `.env.test` | block | Same reason. |
| `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore` | block | Private keys / certificates. |
| `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519` | block | SSH private keys. |
| `.env.example` | allow | The committed template — safe to edit. |
| `docs/adr/*.md` | warn (allow) | ADRs are append-only. Supersede by creating a new ADR with status `Supersedes ADR-NNN`. |
| `pyproject.toml` | warn (allow) | Suggests `uv add <pkg>` instead of direct dep edits. |
| `package.json` | warn (allow) | Suggests `pnpm add <pkg>` instead. |

### 2.3 `auto-format.sh` — PostToolUse formatter dispatcher

| Field | Value |
|---|---|
| Layer | B (Claude Code) |
| Wired in | `.claude/settings.json` → `hooks.PostToolUse[matcher="Edit\|Write"]` |
| Trigger | After Edit or Write completes successfully |
| Input | JSON via stdin: `{ "tool_input": { "file_path": "..." } }` |
| Output | exit 0 always — never blocks Claude |
| Behaviour | Silent format dispatch by extension; swallows formatter errors (`\|\| true`) |
| Test coverage | Implicitly covered by render integrity tests + manual smoke |
| Configuration | Edit the `case` block to add new extensions. |

#### Dispatch table

| Extension | Formatter | Fallback when missing |
|---|---|---|
| `.py` | `ruff format` then `ruff check --fix --quiet` | Try `uv run --no-project ruff format` (if `ruff` not on PATH but `uv` is) |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.json`, `.jsonc`, `.css` | `biome format --write` | `pnpm exec biome format --write --no-errors-on-unmatched` |
| `.tf` | `terraform fmt` | Skip silently |
| `.sh` | `shfmt -w` | Skip silently |
| `.md`, `.yaml`, `.yml`, `.toml` | none (handled by pre-commit on stage) | — |

### 2.4 `scan-agent-configs.sh` — MCP / agent secret scanner

| Field | Value |
|---|---|
| Layer | A (pre-commit framework) — `always_run: true`, also callable manually |
| Wired in | `.pre-commit-config.yaml` → Block 2 |
| Trigger | Every commit; manual run via `bash scripts/hooks/scan-agent-configs.sh [project-dir]` |
| Input | none (scans paths relative to `$CLAUDE_PROJECT_DIR` or `$1` or `pwd`) |
| Output on hit | exit 1, stderr lists hits with file path + line + matched pattern |
| Output on clean | exit 0, no output |
| Test coverage | 2 cases (planted `sk-...` in `.cursor/mcp.json`, clean repo) |
| Rationale | **Sandworm Mode** (Feb 2026) supply-chain attacks plant rogue MCP servers with hardcoded credentials. Pre-commit's standard secret scanners never see those files because they're typically gitignored. |

#### Targets scanned (even when gitignored)

| Path | Why |
|---|---|
| `.claude/settings.json`, `.claude/settings.local.json`, `.claude/.mcp.json` | Claude Code config |
| `.cursor/mcp.json`, `.cursor/settings.json` | Cursor IDE config |
| `.codi/mcp-servers/`, `.codi/codi.yaml` | Codi config |
| `.mcp.json` | Generic MCP config |
| `.windsurf/settings.json` | Windsurf IDE config |
| `.cline/settings.json` | Cline config |
| `.codex/config.json` | Codex CLI config |

#### Patterns checked

| Pattern | Catches |
|---|---|
| `"(api_key\|secret\|token\|password\|access_key\|private_key\|client_secret)": "<≥12 chars not starting with $ or {>"` | JSON-style hardcoded credentials in MCP/agent configs |
| `sk-[A-Za-z0-9]{20+}` | OpenAI API keys |
| `sk-proj-...`, `sk-ant-...` | OpenAI Project / Anthropic API keys |
| `ghp_...`, `github_pat_...`, `gho_...` | GitHub tokens |
| `AKIA[A-Z0-9]{16}` | AWS access keys |
| `AIza[A-Za-z0-9_-]{35}` | Google API keys |
| `xox[baprs]-...` | Slack tokens |
| `BEGIN <type> PRIVATE KEY` | PEM private keys |

### 2.5 `check-branch-name.sh` — pre-push branch policy

| Field | Value |
|---|---|
| Layer | A (pre-commit framework) — `pre-push` stage |
| Wired in | `.pre-commit-config.yaml` → Block 7 |
| Trigger | `git push` |
| Input | none (reads `git rev-parse --abbrev-ref HEAD` and `git config user.name`) |
| Output on allow | exit 0 |
| Output on block | exit 1, stderr explains the expected shape |
| Output on warn | exit 0 + stderr (canonical name suggestion) |
| Test coverage | 9 cases |

#### Format

```
<prefix>/<git-username>/<slug>           ← canonical
<prefix>/<git-username>/<TICKET-ID>-<slug>  ← canonical with ticket reference
```

| Component | Source / format |
|---|---|
| `<prefix>` | one of `feature`, `bugfix`, `chore`, `release`, `hotfix` |
| `<git-username>` | `git config user.name`, lowercased, kebab-cased, alphanumeric+dash only |
| `<TICKET-ID>` | (optional) one uppercase letter + 1–7 uppercase/digits, hyphen, digits — e.g. `RL3-142`, `CBP-7`, `JIRA-99`, `PROD2-1` |
| `<slug>` | lowercase kebab |

#### Decision matrix

| Branch | Verdict |
|---|---|
| `master`, `main`, `develop` | block — committing on a protected branch is forbidden |
| `feature/<user>/<slug>` (slug shape valid + user matches) | allow silently |
| `feature/<user>/<TICKET>-<slug>` | allow silently |
| `feature/<wrong-user>/<slug>` | block — the user segment must equal the normalised git config user.name |
| `feature/<missing-user-segment>` | block — must have `<user>/<slug>` two segments |
| `random-name` | block — bad prefix |
| `chore/<user>/<slug-only>` (no ticket) | allow — `chore/release/*` accept slug-only forms |
| `feature/<user>/UPPERCASE-slug` | warn (allow) — non-canonical but doesn't block; PR-policy CI (Phase 2) is the strict gate |

### 2.6 `no-direct-push.sh` — refuse direct push to protected branches

| Field | Value |
|---|---|
| Layer | A (pre-commit framework) — `pre-push` stage |
| Wired in | `.pre-commit-config.yaml` → Block 7 |
| Trigger | `git push` |
| Input | stdin pre-push refs: `<local_ref> <local_sha> <remote_ref> <remote_sha>` per line |
| Output on allow | exit 0 |
| Output on block | exit 1, stderr suggests the right `gh pr create` command |
| Test coverage | 5 cases |

#### Decision matrix

| `<remote_ref>` | Verdict |
|---|---|
| `refs/heads/master` | block |
| `refs/heads/main` | block |
| `refs/heads/develop` | block |
| `refs/heads/feature/*`, `refs/heads/bugfix/*`, `refs/heads/chore/*`, `refs/heads/release/*`, `refs/heads/hotfix/*` | allow |
| any other (e.g. `refs/tags/...`) | allow |

This is the local mirror of GitHub branch protection. The CI `pr-policy` check (Phase 2) is the authoritative server-side enforcement.

### 2.7 `check-branch-base.sh` — verify branch source

| Field | Value |
|---|---|
| Layer | A (pre-commit framework) — `pre-push` stage |
| Wired in | `.pre-commit-config.yaml` → Block 7 |
| Trigger | `git push` |
| Behaviour | Best-effort `git fetch` then `git merge-base` check |
| Output | Allows offline (degrades when `origin/develop` or `origin/master` is unreachable) |
| Test coverage | Implicitly via the smoke render that uses real branch base |

#### Decision matrix

| Branch prefix | Required descent from |
|---|---|
| `feature/`, `bugfix/`, `chore/`, `release/` | `origin/develop` |
| `hotfix/` | `origin/master` (or `origin/main`) |
| any other | not checked |

### 2.8 `check_file_lines.py` — file-line cap enforcement

| Field | Value |
|---|---|
| Layer | A (pre-commit framework) — `pre-commit` stage |
| Wired in | `.pre-commit-config.yaml` → Block 3 (anti-slop) |
| Trigger | Every commit, on staged files matching the extension list |
| Input | File paths as positional args (pre-commit passes the staged set) |
| Output on allow | exit 0 |
| Output on block | exit 1, stderr lists each oversize file with its line count |
| Test coverage | 4 cases |
| Configuration | `--cap=N` (default 700), `--extensions=ext1,ext2,...` (default: py, ts, tsx, js, jsx, go, rs, java, kt, swift) |

#### Why a 700-line cap

700 lines is the threshold beyond which a single file becomes hard to navigate and reason about. The cap is RL3's standard for code files (`.py`, `.ts`, etc.); documentation files have no cap. AI agents tend to grow files unboundedly when not constrained — this hook is the speed bump.

## 3. Pre-commit configuration blocks

The rendered `.pre-commit-config.yaml` is organized into 7 blocks. Each block has a single concern. The whole `repos:` section is wrapped in `# rl3-templates: managed BEGIN` / `END` markers — `copier update` only refreshes content between the markers. Hooks added outside the markers survive updates.

### Block 1 — Hygiene (always-on, fast)

| Hook | What it does |
|---|---|
| `trailing-whitespace` | Strip trailing spaces. |
| `end-of-file-fixer` | Ensure file ends with newline. |
| `mixed-line-ending` (`--fix=lf`) | Normalise to LF. |
| `check-merge-conflict` | Block files with `<<<<<<<` markers. |
| `check-case-conflict` | Block files that would conflict on case-insensitive filesystems. |
| `fix-byte-order-marker` | Strip BOM. |
| `check-yaml` (`--unsafe`) | YAML syntax (allows custom tags). |
| `check-toml` | TOML syntax. |
| `check-json` | JSON syntax (excludes `tsconfig*.json` which often have comments). |
| `check-added-large-files` (`--maxkb=1000`) | Block files >1MB unless `git lfs`. |
| `detect-private-key` | Block private key file content. |
| `debug-statements` | Block `pdb`, `breakpoint()`, raw `print` in `.py`. |
| `no-commit-to-branch` | Block local commits on `master`, `develop`, `release/*`. |
| `check-executables-have-shebangs` | Executable files must have `#!`. |

### Block 2 — Secrets and supply chain

| Hook | What it does |
|---|---|
| `gitleaks` (`--no-banner`) | Full diff secret scan with the upstream ruleset + `.gitleaks.toml` allowlist. |
| `scan-agent-configs` (custom) | Sandworm-mode mitigation (see §2.4). |
| `forbid-env-file` | Block any `.env` or `.env.*` (except `.env.example`). |
| `forbid-credentials` | Block `.pem`, `.key`, `.p12`, `.pfx`, `.jks`, `.keystore`, `id_rsa`, `credentials.json`. |

### Block 3 — Anti-slop (AI-specific)

| Hook | What it does |
|---|---|
| `file-line-cap` | 700-line cap (see §2.8). |
| `orphan-todo` | Block `TODO` not followed by `(<TICKET>-N)`. |
| `not-implemented-stub` | Block `raise NotImplementedError` and `throw new Error("not implemented")`. |
| `forbid-coauthor-claude` | Block `Co-Authored-By: Claude` (or any model attribution) in committed content. |
| `forbid-edits-to-generated` | Block edits to `routeTree.gen.ts`, `frontend/src/client/**`, `*_pb2.py`, `*.lock`, `.copier-answers.yml`. |

### Block 4 — Python (rendered when `has_python`)

| Hook | What it does |
|---|---|
| `ruff` (`--fix`) | Lint + autofix (rules `E, W, F, I, N, UP, B, C4, SIM, RUF, ARG001` + `S` security category). |
| `ruff-format` | Format. |
| `ruff-restage` (custom) | `git add` files modified by ruff so the commit picks up the fixes. |
| `pyright` / `ty` / `mypy-strict` | Selected type checker per `python_type_checker` flag. |
| `bandit` (conditional) | Deep SAST when `python_security_scanner ∈ {bandit, both}`. |

### Block 5 — TypeScript (rendered when `has_typescript`)

| Hook | What it does |
|---|---|
| `biome-check` | Lint + format (replaces ESLint + Prettier). |

### Block 6 — Infra and docs

| Hook | What it does |
|---|---|
| `hadolint-docker` (when `has_docker`) | Dockerfile linter. |
| `yamllint` | YAML lint per `.yamllint.yaml`. |
| `actionlint` (when `has_github_actions`) | GitHub Actions workflow validator. |
| `typos` / `codespell` | Spell check per `spellchecker` flag. |
| `shellcheck` (`-S warning`) | Shell script linter. |
| `terraform_fmt` + `terraform_tflint` (when `has_terraform`) | Terraform check. |
| `ansible-lint` (when `has_ansible`) | Ansible check. |

### Block 7 — commit-msg + pre-push tier

| Hook | Stage | What it does |
|---|---|---|
| `conventional-pre-commit` | commit-msg | Strict Conventional Commits: `feat \| fix \| docs \| refactor \| test \| chore \| perf \| ci \| build \| style \| revert`. |
| `commit-msg-no-coauthor-claude` | commit-msg | Reject `Co-Authored-By: Claude` trailer. |
| `commit-msg-length` | commit-msg | First line ≤ 72 chars. |
| `branch-naming` | pre-push | See §2.5. |
| `no-direct-push` | pre-push | See §2.6. |
| `branch-source-base` | pre-push | See §2.7. |
| `tsc-noemit` | pre-push (when `has_typescript` + `include_pre_push_tier`) | TypeScript type check. |
| `pip-audit` | pre-push (when `has_python` + `include_pre_push_tier`) | OSV CVE scan against `uv.lock`. |
| `pytest-cov` | pre-push (when `has_python` + `include_pre_push_tier`) | `pytest --cov-fail-under={{ coverage_gate }}`. |

## 4. `.claude/settings.json`

The rendered Claude Code settings file has three sections.

### 4.1 `permissions.deny` — 37 entries

| Group | Entries | Reason |
|---|---|---|
| Direct push to protected branches | `git push origin <prod>*`, `git push * <prod>`, `git push origin HEAD:<prod>*`, etc. (×6) | Three-layer block. |
| `--no-verify` and force-push variants | `git push --no-verify*`, `git push --force *`, `git push -f *`, `git commit --no-verify*`, `git commit -n *` (×5) | Per the non-negotiables. |
| Checkout/switch onto protected | `git checkout <prod>`, `git checkout main`, `git switch <prod>`, etc. (×6) | Stay on a feature branch. |
| Destructive git | `git reset --hard *`, `git rebase * <prod>` (×3) | Destructive. |
| `git config --global` | `git config --global *` (×1) | User's global config. |
| Catastrophic shell | `rm -rf /*`, `rm -rf ~*`, `chmod -R *` (×3) | Self-explanatory. |
| Forbidden package managers | `pip install *` (×1) | Use `uv add`. |
| Direct edits to env / secrets | `Edit(.env)`, `Edit(.env.local)`, `Edit(.env.production)`, etc. + `Write(...)` (×12) | Defence in depth (also in `guard-write.sh`). |

### 4.2 `permissions.allow` — 15 entries

| Group | Entries | Reason |
|---|---|---|
| Force-with-lease on feature branches | `git push --force-with-lease origin feature/*`, `bugfix/*`, `chore/*`, `release/*`, `hotfix/*` (×5) | Safe force-push for collaboration. |
| Branch creation | `git checkout -b <prefix>/*`, `git switch -c <prefix>/*` (×10) | The canonical workflow. |

### 4.3 `hooks` — 3 lifecycle events

| Event | Matcher | Script | Timeout |
|---|---|---|---|
| `PreToolUse` | `Bash` | `scripts/hooks/guard-bash.sh` (§2.1) | 5 s |
| `PreToolUse` | `Edit\|Write\|NotebookEdit` | `scripts/hooks/guard-write.sh` (§2.2) | 5 s |
| `PostToolUse` | `Edit\|Write` | `scripts/hooks/auto-format.sh` (§2.3) | 10 s |

All hook commands prefix the path with `${CLAUDE_PROJECT_DIR:-.}` for portable resolution.

## 5. Branching policy (consolidated reference)

### 5.1 PR routing matrix

| Source | Target | Reviewers | Use case |
|---|---|---|---|
| `feature/<user>/<slug>` | `develop` | 1 | New feature |
| `bugfix/<user>/<slug>` | `develop` | 1 | Non-urgent bug fix |
| `chore/<user>/<slug>` | `develop` | 1 | Tooling, deps, docs |
| `release/<user>/v<x.y.z>` | `master` | 2 | Release PR |
| `develop` | `master` | 2 | Integration PR |
| `hotfix/<user>/<slug>` | `master` | 1 (fast) | Production fix |
| `hotfix/<user>/<slug>` (auto-opened by CI) | `develop` | 1 | Mandatory back-merge |

### 5.2 Branch creation rules

| Branch prefix | Branched from |
|---|---|
| `feature/`, `bugfix/`, `chore/`, `release/` | `origin/develop` |
| `hotfix/` | `origin/master` |

### 5.3 Hotfix flow

```
1. Production incident detected
2. git fetch origin && git checkout -b hotfix/<user>/<TICKET>-<slug> origin/master
3. Edit, test locally
4. git commit -m "fix(<scope>): <description>"
5. git push origin hotfix/<user>/<TICKET>-<slug>
6. gh pr create --base master --head hotfix/<user>/<TICKET>-<slug>
7. Fast-track review (1 reviewer)
8. Merge → release pipeline triggers
9. CI auto-opens PR hotfix → develop (Phase 2 _ops-hotfix-backmerge.yml)
10. Review back-merge, merge to develop
```

No `--no-verify`. No direct push. No admin override. The hotfix flow is the only fast path; admin override is reserved for the two named human admins for genuine emergencies.

## 6. Copier prompts and flags

These are the answers `copier copy` collects. Defaults shown in **bold**.

### 6.1 Identity

| Prompt | Type | Default | Purpose |
|---|---|---|---|
| `project_slug` | str | (required) | Repo name in kebab-case. Used in `CLAUDE.md` and docs. |
| `ticket_prefix` | str | **`RL3`** | Used in commit messages and `TODO(<PREFIX>-N)` references. |

### 6.2 Stack

| Prompt | Type | Default | Effect |
|---|---|---|---|
| `has_python` | bool | **`false`** | Renders Block 4 + pip-audit + pytest pre-push. |
| `has_typescript` | bool | **`false`** | Renders Block 5 + tsc pre-push. |
| `backend_dir` | str | **`backend`** | Subdir for the Python project (asked when `has_python`). |
| `frontend_dir` | str | **`frontend`** | Subdir for the TypeScript project (asked when `has_typescript`). |
| `has_terraform` | bool | **`false`** | Renders `terraform_fmt` + `tflint`. |
| `has_ansible` | bool | **`false`** | Renders `ansible-lint`. |
| `has_docker` | bool | **`true`** | Renders `hadolint-docker`. |
| `has_github_actions` | bool | **`true`** | Renders `actionlint`. |

### 6.3 Quality gates

| Prompt | Type | Choices / Default | Effect |
|---|---|---|---|
| `python_type_checker` | choice | `pyright` (default), `ty`, `mypy-strict`, `none` | Selects which type checker hook block 4 emits. |
| `python_security_scanner` | choice | `ruff-S` (default), `bandit`, `both`, `none` | `ruff-S` covers ~90% of bandit's checks; `both` for deep XML / serialization / subprocess SAST. |
| `spellchecker` | choice | `typos` (default), `codespell`, `none` | `typos` is Rust-based, ~10× faster than codespell. |
| `coverage_gate` | int | **80** | `pytest --cov-fail-under` threshold. |
| `include_pre_push_tier` | bool | **`true`** | Toggles pip-audit + pytest cov + tsc on pre-push. Disable for repos where local pre-push is too slow. |

### 6.4 Anti-slop

| Prompt | Type | Default | Effect |
|---|---|---|---|
| `enable_anti_slop` | bool | **`true`** | Toggles Block 3 (file-line cap, orphan-TODO, NotImplementedError, Co-Authored-By Claude scan, generated-file edit blocker). |
| `file_line_cap` | int | **700** | Maximum lines for `.py`, `.ts`, `.tsx`, `.js`, `.jsx`, `.go`, `.rs` files. |

### 6.5 Branch policy

| Prompt | Type | Choices / Default | Effect |
|---|---|---|---|
| `production_branch` | choice | `master` (default), `main` | Threads into `no-commit-to-branch`, `no-direct-push.sh`, Claude deny-list, `setup-branch-protection.sh`. |
| `integration_branch` | str | **`develop`** | Same. |

## 7. Testing

### 7.1 Validation suite (`tests/validate.sh`)

Renders a fullstack sandbox into `/tmp/rl3-validation`, exercises every hook script with positive AND negative inputs, plus structural checks on the rendered configs. Writes `STATUS.md` with per-test results.

```bash
bash tests/validate.sh
cat /tmp/rl3-validation/STATUS.md
```

Test count: 91 across 9 categories. The latest archived run is in `docs/<timestamp>_[REPORT]_baseline-validation.md`.

### 7.2 When to run

- Before tagging a new template version.
- After any change to `baseline/scripts/hooks/`.
- After any change to `baseline/.pre-commit-config.yaml.jinja` or `baseline/.claude/settings.json.jinja`.
- After any change to `copier.yml` prompts or `_tasks`.

## 8. Updating a consumer repo

```bash
copier update --skip-answered
```

The weekly `.github/workflows/template-drift.yml` runs this automatically and opens a PR titled `chore(template): sync rl3-templates baseline`. Conflict resolution uses 3-way merge; conflicts surface as `.rej` files.

**Always run `pre-commit run --all-files` after merging a template-sync PR** to catch any newly-introduced rules that the diff didn't apply cleanly.

## 9. Reference: file inventory

The rendered `baseline` produces these files in the consumer repo. The first column lists what `rl3-templates` ships; the second is the rendered name in the consumer.

| In `rl3-templates/baseline/` | In consumer | Templated? |
|---|---|---|
| `.pre-commit-config.yaml.jinja` | `.pre-commit-config.yaml` | yes |
| `.claude/settings.json.jinja` | `.claude/settings.json` | yes |
| `.copier-answers.yml.jinja` | `.copier-answers.yml` | yes (Copier-managed) |
| `CLAUDE.md.jinja` | `CLAUDE.md` | yes |
| `.gitleaks.toml` | `.gitleaks.toml` | no |
| `.yamllint.yaml` | `.yamllint.yaml` | no |
| `.codespellrc` | `.codespellrc` | no |
| `.github/workflows/template-drift.yml` | `.github/workflows/template-drift.yml` | no |
| `scripts/setup-branch-protection.sh` | `scripts/setup-branch-protection.sh` | no |
| `scripts/hooks/guard-bash.sh` | `scripts/hooks/guard-bash.sh` | no |
| `scripts/hooks/guard-write.sh` | `scripts/hooks/guard-write.sh` | no |
| `scripts/hooks/auto-format.sh` | `scripts/hooks/auto-format.sh` | no |
| `scripts/hooks/scan-agent-configs.sh` | `scripts/hooks/scan-agent-configs.sh` | no |
| `scripts/hooks/check-branch-name.sh` | `scripts/hooks/check-branch-name.sh` | no |
| `scripts/hooks/no-direct-push.sh` | `scripts/hooks/no-direct-push.sh` | no |
| `scripts/hooks/check-branch-base.sh` | `scripts/hooks/check-branch-base.sh` | no |
| `scripts/hooks/check_file_lines.py` | `scripts/hooks/check_file_lines.py` | no |

17 files total. Every consumer repo ends up byte-identical for the static files and consistent (per its answers) for the templated files.
