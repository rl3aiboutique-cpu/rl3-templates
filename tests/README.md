# tests/

End-to-end validation harness for the `baseline` template.

## What lives here

| File | Purpose |
|---|---|
| `validate.sh` | Renders a fullstack sandbox into `/tmp/rl3-validation`, exercises every hook with positive AND negative inputs, writes `STATUS.md` with per-test results. |

## Run it

```bash
bash tests/validate.sh
cat /tmp/rl3-validation/STATUS.md
```

Exits with the test-pass count printed at the end. The latest archived report lives in `docs/<timestamp>_[REPORT]_baseline-validation.md`.

## What it covers

- All 8 hook scripts (`scripts/hooks/*.sh`, `*.py`).
- The rendered `.pre-commit-config.yaml` — required-hooks coverage + `pre-commit validate-config`.
- The rendered `.claude/settings.json` — deny-list completeness + hook command shape.
- File rendering integrity (every expected file present + executable).

Test count: 91 across 9 categories (see `STATUS.md` summary).

## When to run

- Before tagging a new template version.
- After any change to `baseline/scripts/hooks/`.
- After any change to `baseline/.pre-commit-config.yaml.jinja` or `baseline/.claude/settings.json.jinja`.

## Adding new tests

`validate.sh` uses small helper functions per hook category:

- `gb_block / gb_allow` — guard-bash test cases
- `gw_block / gw_allow` — guard-write test cases
- `bn_test`            — branch-name test cases
- `ndp_test`           — no-direct-push test cases
- `run_lines`          — file-line cap test cases

Add cases by appending to the matrix sections (lines 80–180 of `validate.sh`). Names with `|` characters break the Markdown table; use words like "pipe" instead.
