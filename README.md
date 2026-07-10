# zt

Run Zebra's CI gate **locally**, so you can tell whether a PR will pass CI before
you push.

`zt` shells out to `cargo` in the current workspace and runs the same checks
[ZcashFoundation/zebra](https://github.com/ZcashFoundation/zebra)'s CI runs in
`.github/workflows/` — formatting, clippy (`-D warnings`), `check --locked`,
docs, the feature powerset, unit tests, unused-dependency and license audits, and
an MSRV build — then prints a per-check pass/fail summary.

It's the companion to [`ziff`](https://github.com/ZcashFoundation/ziff): on a PR
you run **`ziff`** (public-API + dependency diff, changelog draft) and **`zt`**
(the CI gate) side by side.

## Install

`zt` is a single Python 3 script — put it on your `PATH`:

```sh
git clone https://github.com/ZcashFoundation/zt
ln -s "$PWD/zt/zt" ~/.local/bin/zt      # or copy it anywhere on PATH
```

No build step. It uses only the Python standard library.

## Usage

```sh
zt                 # run the whole gate, stopping at the first failure
zt --keep-going    # run every check even after a failure (a full report)
zt --fast          # skip the slow checks (test, hack, udeps, msrv)
zt fmt clippy doc  # run only these checks
zt --skip test     # run everything except the named checks
zt --list          # list the checks (grouped, with their source workflow)
```

Run the heavy builds where they're fast — the same host you run `ziff` on:

```sh
ssh build-host 'cd path/to/zebra && ROCKSDB_LIB_DIR=/usr/lib/ zt'
```

`ROCKSDB_LIB_DIR=/usr/lib/` links the system RocksDB instead of recompiling the
bundled one, exactly as CI does. Keep `fmt` correct on your source-of-truth host
too (`zt fmt`, or `cargo fmt --all`).

## The checks

`zt --list` prints them grouped, each annotated with the CI workflow it mirrors:

| group | checks |
| --- | --- |
| format | `fmt` |
| lint | `clippy` (all features), `clippy-no-default`, `check-locked`, `hack` |
| docs | `doc`, `codespell` (optional) |
| test | `test` (nextest `ci` profile) |
| supply-chain | `udeps`, `deny`, `vet` (optional — CI disabled it) |
| msrv | `msrv` (build on the MSRV toolchain) |

Each check probes its prerequisites (`cargo-nextest`, `cargo-hack`,
`cargo-udeps` + nightly, `cargo-deny`, the MSRV toolchain, `codespell`) and
**skips** itself with a note if they're absent, rather than failing the run.

## Exit status

- `0` — every selected check passed (skipped checks don't fail the run).
- `1` — at least one check failed.
- `2` — usage error.

## Scope

`zt` runs a curated gate, not a GitHub Actions YAML interpreter. When Zebra's CI
adds or changes a check, update `zt`'s check list to match — the workflow is the
contract.

## License

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT) at
your option.
