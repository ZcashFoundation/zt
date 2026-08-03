#!/usr/bin/env bash
# Integration tests for zt.
#
# Exercises the CLI surface and the check runner with a fake `cargo` on PATH, so
# no real build (or Rust toolchain) is needed. Run from anywhere:  tests/run.sh
set -uo pipefail

ZT=${ZT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/zt"}
pass=0
fail=0

ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail + 1)); }
assert_eq()       { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (got '$1', want '$2')"; fi; }
assert_contains() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3 (output missing: $2)" ;; esac; }

# ── CLI surface ───────────────────────────────────────────────
assert_eq "$("$ZT" --version)" "zt 0.1.0" "--version"
assert_contains "$("$ZT" --list --no-color)" "clippy" "--list shows checks"
assert_contains "$("$ZT" --list --no-color)" "(lint.yml)" "--list cites source workflow"
"$ZT" --help --no-color >/dev/null; assert_eq "$?" "0" "--help exits 0"
"$ZT" bogus-check --no-color >/dev/null 2>&1; assert_eq "$?" "2" "unknown check -> exit 2"

# ── the script itself is valid Python ─────────────────────────
if python3 -m py_compile "$ZT" 2>/dev/null; then ok "py_compile"; else bad "py_compile"; fi

# ── runner, driven by a fake cargo ────────────────────────────
work=$(mktemp -d)
bin=$(mktemp -d)
trap 'rm -rf "$work" "$bin"' EXIT
printf '[package]\nname = "x"\n' > "$work/Cargo.toml"

# A fake cargo/rustfmt that exit with $FAKE_RC (default 0).
cat > "$bin/cargo" <<'EOF'
#!/usr/bin/env bash
exit "${FAKE_RC:-0}"
EOF
cp "$bin/cargo" "$bin/rustfmt"
chmod +x "$bin/cargo" "$bin/rustfmt"

out=$(cd "$work" && PATH="$bin:$PATH" FAKE_RC=0 "$ZT" fmt --no-color); rc=$?
assert_eq "$rc" "0" "check passes -> exit 0"
assert_contains "$out" "pass" "passing check reports pass"

out=$(cd "$work" && PATH="$bin:$PATH" FAKE_RC=1 "$ZT" fmt --no-color); rc=$?
assert_eq "$rc" "1" "check fails -> exit 1"
assert_contains "$out" "fail" "failing check reports fail"

# A missing tool skips the check, but a *required* check that never ran leaves
# "will CI pass?" unanswered, so the run must not report success. Use a PATH with
# just python + the fake cargo, so cargo-hack is absent no matter the host.
pydir=$(dirname "$(command -v python3)")
out=$(cd "$work" && PATH="$bin:$pydir" "$ZT" hack --no-color); rc=$?
assert_eq "$rc" "3" "missing required tool -> exit 3 (incomplete)"
assert_contains "$out" "skip" "missing tool reports skip"
assert_contains "$out" "incomplete" "missing required tool is called out"
assert_contains "$out" "cargo-hack not found" "startup lists unresolved tools"

# --allow-missing restores the old behaviour for a deliberately partial toolset.
out=$(cd "$work" && PATH="$bin:$pydir" "$ZT" hack --allow-missing --no-color); rc=$?
assert_eq "$rc" "0" "missing required tool + --allow-missing -> exit 0"

# An optional check (codespell, vet) is allowed to be absent: it skips quietly.
out=$(cd "$work" && PATH="$bin:$pydir" "$ZT" codespell --no-color); rc=$?
assert_eq "$rc" "0" "missing optional tool -> exit 0"
assert_contains "$out" "skip" "missing optional tool reports skip"

# A real failure still outranks incompleteness.
out=$(cd "$work" && PATH="$bin:$pydir" FAKE_RC=1 "$ZT" fmt hack --keep-going --no-color); rc=$?
assert_eq "$rc" "1" "failure outranks incomplete -> exit 1"

# --fast drops the slow checks.
assert_contains "$(cd "$work" && "$ZT" --list --no-color)" "test" "test check exists"
out=$(cd "$work" && PATH="$bin:$pydir" "$ZT" --fast --keep-going --no-color 2>/dev/null)
case "$out" in *"nextest"*) bad "--fast still ran the slow test check" ;; *) ok "--fast skips slow checks" ;; esac

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
