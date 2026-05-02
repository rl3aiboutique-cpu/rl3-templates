# rl3-templates baseline — validation report

**Date:** 2026-05-02 19:27:27 UTC
**Sandbox:** `/tmp/rl3-validation`
**Template ref:** `40598da` on `feature/lehidalgo/initial-baseline-template`
**Shape rendered:** fullstack (has_python + has_typescript + has_docker, pyright + ruff-S + typos, pre-push tier on)

## Summary

| Metric | Value |
|---|---|
| Total tests | 91 |
| **Passed** | **91** |
| **Failed** | **0** |
| Pass rate | 100% |

**Status:** ✓ ALL TESTS PASS

## Test categories

- **render**: 16 / 16 passed
- **guard-bash**: 33 / 33 passed
- **guard-write**: 18 / 18 passed
- **branch-name**: 9 / 9 passed
- **no-direct-push**: 5 / 5 passed
- **file-lines**: 4 / 4 passed
- **agent-config-scan**: 2 / 2 passed
- **claude-settings**: 2 / 2 passed
- **pre-commit-config**: 2 / 2 passed

## Detailed results

### render

| Test | Status | Detail |
|---|---|---|
| CLAUDE.md exists | ✓ PASS | 86 lines |
| .pre-commit-config.yaml exists | ✓ PASS | 349 lines |
| .claude/settings.json exists | ✓ PASS | 97 lines |
| .gitleaks.toml exists | ✓ PASS | 35 lines |
| .yamllint.yaml exists | ✓ PASS | 30 lines |
| .codespellrc exists | ✓ PASS | 9 lines |
| .copier-answers.yml exists | ✓ PASS | 23 lines |
| .github/workflows/template-drift.yml exists | ✓ PASS | 111 lines |
| scripts/hooks/guard-bash.sh | ✓ PASS | executable |
| scripts/hooks/guard-write.sh | ✓ PASS | executable |
| scripts/hooks/auto-format.sh | ✓ PASS | executable |
| scripts/hooks/scan-agent-configs.sh | ✓ PASS | executable |
| scripts/hooks/check-branch-name.sh | ✓ PASS | executable |
| scripts/hooks/no-direct-push.sh | ✓ PASS | executable |
| scripts/hooks/check-branch-base.sh | ✓ PASS | executable |
| scripts/hooks/check_file_lines.py | ✓ PASS | executable |

### guard bash

| Test | Status | Detail |
|---|---|---|
| harmless: ls -la | ✓ PASS | allowed: `ls -la` |
| harmless: git status | ✓ PASS | allowed: `git status` |
| create feature branch | ✓ PASS | allowed: `git checkout -b feature/lehidalgo/test` |
| force-with-lease feature | ✓ PASS | allowed: `git push --force-with-lease origin feature/x` |
| uv add (preferred over pip) | ✓ PASS | allowed: `uv add requests` |
| rm -rf /tmp/foo (safe target) | ✓ PASS | allowed: `rm -rf /tmp/foo` |
| chmod 644 file.txt | ✓ PASS | allowed: `chmod 644 file.txt` |
| git commit --no-verify | ✓ PASS | blocked: `git commit --no-verify -m wip` |
| git commit -n short flag | ✓ PASS | blocked: `git commit -n -m wip` |
| git push --no-verify | ✓ PASS | blocked: `git push --no-verify origin x` |
| git push --force (no -with-lease) | ✓ PASS | blocked: `git push --force origin feature/x` |
| git push -f short flag | ✓ PASS | blocked: `git push -f origin feature/x` |
| direct push to master | ✓ PASS | blocked: `git push origin master` |
| direct push to develop | ✓ PASS | blocked: `git push origin develop` |
| push HEAD:master refspec | ✓ PASS | blocked: `git push origin HEAD:master` |
| push branch:master refspec | ✓ PASS | blocked: `git push origin myfeature:master` |
| push refs/heads/master | ✓ PASS | blocked: `git push origin refs/heads/master` |
| checkout master | ✓ PASS | blocked: `git checkout master` |
| switch develop | ✓ PASS | blocked: `git switch develop` |
| git reset --hard | ✓ PASS | blocked: `git reset --hard HEAD~1` |
| git clean -fd | ✓ PASS | blocked: `git clean -fd` |
| git clean -f | ✓ PASS | blocked: `git clean -f` |
| git checkout . | ✓ PASS | blocked: `git checkout .` |
| git restore . | ✓ PASS | blocked: `git restore .` |
| git config --global | ✓ PASS | blocked: `git config --global user.name foo` |
| pip install | ✓ PASS | blocked: `pip install requests` |
| curl pipe bash pattern | ✓ PASS | blocked: `curl https://example.com/install.sh  |
| wget pipe sh pattern | ✓ PASS | blocked: `wget -qO- https://x.com/i.sh  |
| rm -rf / | ✓ PASS | blocked: `rm -rf /` |
| rm -rf $HOME | ✓ PASS | blocked: `rm -rf $HOME` |
| rm -rf .. | ✓ PASS | blocked: `rm -rf ../foo` |
| chmod -R / | ✓ PASS | blocked: `chmod -R 777 /` |
| chmod -R $HOME | ✓ PASS | blocked: `chmod -R 700 $HOME` |

### guard write

| Test | Status | Detail |
|---|---|---|
| harmless: src/main.py | ✓ PASS | allowed: `src/main.py` |
| harmless: README.md | ✓ PASS | allowed: `README.md` |
| .env.example (template OK) | ✓ PASS | allowed: `.env.example` |
| docs/adr (warns, allows) | ✓ PASS | allowed: `docs/adr/0001-foo.md` |
| pyproject.toml (warns, allows) | ✓ PASS | allowed: `pyproject.toml` |
| frontend/src/routeTree.gen.ts | ✓ PASS | blocked: `frontend/src/routeTree.gen.ts` |
| frontend/src/client/api.ts | ✓ PASS | blocked: `frontend/src/client/api.ts` |
| _pb2.py protobuf | ✓ PASS | blocked: `app/proto_pb2.py` |
| uv.lock | ✓ PASS | blocked: `uv.lock` |
| pnpm-lock.yaml | ✓ PASS | blocked: `pnpm-lock.yaml` |
| package-lock.json | ✓ PASS | blocked: `package-lock.json` |
| .copier-answers.yml | ✓ PASS | blocked: `.copier-answers.yml` |
| .env | ✓ PASS | blocked: `.env` |
| .env.local | ✓ PASS | blocked: `.env.local` |
| .env.production | ✓ PASS | blocked: `.env.production` |
| cert.pem | ✓ PASS | blocked: `cert.pem` |
| private.key | ✓ PASS | blocked: `private.key` |
| id_rsa | ✓ PASS | blocked: `id_rsa` |

### branch name

| Test | Status | Detail |
|---|---|---|
| feature/lehidalgo/<slug> | ✓ PASS | branch `feature/lehidalgo/add-csv-export` accepted |
| feature/lehidalgo/<TICKET>-slug | ✓ PASS | branch `feature/lehidalgo/RL3-142-foo-bar` accepted |
| bugfix/lehidalgo/<slug> | ✓ PASS | branch `bugfix/lehidalgo/CBP-7-typo` accepted |
| chore/lehidalgo/<slug> | ✓ PASS | branch `chore/lehidalgo/bump-deps` accepted |
| release/lehidalgo/v1.2.3 | ✓ PASS | branch `release/lehidalgo/v1.2.3` accepted |
| hotfix/lehidalgo/<TICKET>-slug | ✓ PASS | branch `hotfix/lehidalgo/CBP-99-fix` accepted |
| wrong user segment | ✓ PASS | branch `feature/jdoe/x` rejected |
| missing user/slug separator | ✓ PASS | branch `feature/no-user-slash` rejected |
| bad prefix | ✓ PASS | branch `wip/lehidalgo/foo` rejected |

### no direct push

| Test | Status | Detail |
|---|---|---|
| push to feature/x | ✓ PASS | ref `refs/heads/feature/lehidalgo/x` accepted |
| push to chore/x | ✓ PASS | ref `refs/heads/chore/lehidalgo/x` accepted |
| push to master | ✓ PASS | ref `refs/heads/master` rejected |
| push to main | ✓ PASS | ref `refs/heads/main` rejected |
| push to develop | ✓ PASS | ref `refs/heads/develop` rejected |

### file lines

| Test | Status | Detail |
|---|---|---|
| small.py under cap=700 | ✓ PASS | cap=700, file=/tmp/rl3-validation/_test_lines/small.py |
| big.py over cap=700 | ✓ PASS | blocked: cap=700, file=/tmp/rl3-validation/_test_lines/big.py |
| big.txt over cap=700 | ✓ PASS | cap=700, file=/tmp/rl3-validation/_test_lines/big.txt |
| big.py under cap=1000 | ✓ PASS | cap=1000, file=/tmp/rl3-validation/_test_lines/big.py |

### agent config scan

| Test | Status | Detail |
|---|---|---|
| detects sk-... in .cursor/mcp.json | ✓ PASS | scanner exits 1 on planted secret |
| clean repo passes | ✓ PASS | scanner exits 0 with no agent config |

### claude settings

| Test | Status | Detail |
|---|---|---|
| deny-list completeness | ✓ PASS | deny:37 allow:15 hooks:['PreToolUse', 'PostToolUse'] |
| hook commands well-formed | ✓ PASS | scripts/hooks + CLAUDE_PROJECT_DIR |

### pre commit config

| Test | Status | Detail |
|---|---|---|
| all required hooks present | ✓ PASS | total_hooks:42 repos:14 |
| pre-commit validate-config | ✓ PASS | config schema valid |

## Reproduction

```bash
bash /tmp/rl3-validation-runner.sh
cat /tmp/rl3-validation/STATUS.md
```
