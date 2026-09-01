---
name: zt
description: >-
  Run Zebra's CI gate locally with the `zt` tool to tell whether a PR will pass
  CI before pushing: fmt, clippy (-D warnings), check --locked, doc, feature
  powerset (cargo-hack), unit tests (nextest ci profile), unused deps
  (cargo-udeps), licenses/advisories (cargo-deny), and an MSRV build — each
  mirrored from `.github/workflows/`. Run the heavy builds on the fast remote
  host. Use when the user asks to run the gate, emulate CI, or verify a branch/PR
  before pushing. Pairs with the `zc` skill on a PR.
---

# Run Zebra's CI gate with `zt`

`zt` shells out to `cargo` in the current workspace and runs the same checks
Zebra's CI runs (`.github/workflows/lint.yml`, `tests-unit.yml`,
`test-crates.yml`, `docs-check.yml`), reporting a per-check pass/fail summary.
It sits next to `zc`: on a PR you run **`zc`** (public-API + dependency diff,
changelog draft) and **`zt`** (the CI gate) side by side.

Needs `zt` on `PATH`. Each check skips itself if its tool or toolchain is
missing, so a partial toolset still gives useful output.

## Where it runs

Run the heavy builds where they're fast — the same host you run `zc` on:

```sh
ssh build-host 'cd path/to/zebra && ROCKSDB_LIB_DIR=/usr/lib/ zt'
```

Whatever gets the code there must carry the working tree, not just the last
commit. A gate run against a stale checkout reports on code you are not about to
push, and reports it green. Prefer a wrapper that syncs and verifies before
running over a bare `ssh`, if your setup has one.

`ROCKSDB_LIB_DIR=/usr/lib/` links the system RocksDB instead of recompiling the
bundled one, exactly as CI does. Keep `fmt` correct on the host you commit from:
a one-way sync discards a formatting fix made on the far side, so run `zt fmt`
there too, or `cargo fmt --all` before committing.

## Usage

```
zt                 # whole gate, stop at first failure
zt --keep-going    # run every check, even after a failure (good for a full report)
zt --fast          # skip the slow checks (test, hack, udeps, msrv)
zt fmt clippy doc  # only these checks
zt --skip test     # everything except the named checks
zt --list          # list the checks (grouped, with the source workflow) and exit
```

## The checks

`zt --list` prints them grouped: **format** (fmt), **lint** (clippy all-features,
clippy no-default, check --locked, hack), **docs** (doc, codespell), **test**
(nextest ci profile), **supply-chain** (udeps, deny; vet is optional — CI
disabled it in #10930), **msrv** (build on the MSRV toolchain).

## Interpreting output

- Exit 0 = every selected check passed. Exit 1 = at least one failed. Skipped
  checks (missing tool) don't fail the run — install the tool and re-run if you
  need that check.
- `clippy` runs with `-D warnings`, so a warning is a failure — read the output.
- A red check means CI will fail the same way; fix and re-run before pushing.

## Notes

- Reach for `--fast` for a quick pre-commit pass, and the full `zt --keep-going`
  before opening or updating a PR (see the "run the gate before every push"
  rule).
- `zt` runs a curated gate, not a YAML interpreter. If CI adds or changes a
  check, update `zt`'s check list to match — the workflow is the contract.
