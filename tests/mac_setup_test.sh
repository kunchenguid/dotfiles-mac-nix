#!/bin/bash
#
# Regression test for setup/mac.sh.
#
# setup/mac.sh installs Nix and activates a real nix-darwin system, so it can
# never be run for real in CI or in a dev checkout. This test instead runs
# the actual script with PATH masked down to a directory of stub
# executables (curl, sh, nix, darwin-rebuild, sudo, bash) that simulate a
# fresh Mac: they record every invocation to a log and fake just enough
# filesystem state (a profile script, a "nix" binary) for the script's own
# logic to progress, without ever touching the real network, Nix store,
# Homebrew, sudo, or system state. The harness guards every intentional
# harness/stub write against sandbox escapes, re-homes NVM_DIR under the
# sandboxed HOME, and clears inherited shell startup hooks before invoking the
# script under test.
#
# Run: bash tests/mac_setup_test.sh

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)
# Resolved before PATH gets masked below, so the scenario runner always
# invokes the real interpreter on the script under test -- never the stub
# "bash" that simulates the nvm step's PATH-resolved `bash` call.
REAL_BASH=$(command -v bash)

FAILURES=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if ! grep -qF -- "$needle" <<<"$haystack"; then
    fail "$msg -- expected to find: $needle"
    return 1
  fi
  return 0
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    fail "$msg -- expected NOT to find: $needle"
    return 1
  fi
  return 0
}

# Counts lines whose *start* matches an extended regex, so a stub's own log
# line (e.g. "nix ...") isn't double-counted against the "sudo nix ..."
# wrapper line that also contains the same text as a substring.
assert_line_count() {
  local haystack="$1" pattern="$2" expected="$3" msg="$4"
  local actual
  actual=$(grep -cE -- "^$pattern" <<<"$haystack" || true)
  if [ "$actual" -ne "$expected" ]; then
    fail "$msg -- expected $expected line(s) matching '^$pattern', got $actual"
    return 1
  fi
  return 0
}

sandbox_guard_violation() {
  local target="$1"
  local abs_sandbox="${2:-unknown}"

  echo "HERMETIC VIOLATION: refusing to write outside sandbox: $target (sandbox: $abs_sandbox)" >&2
  exit 1
}

# Refuse harness writes that escape the per-scenario temp sandbox. Stubs source
# the generated copy at $SANDBOX_GUARD and call guard_write_path before writing.
guard_write_path() {
  local target="$1"
  local abs_sandbox current raw_path component resolved
  local -a components

  if [ -z "${SANDBOX_ROOT:-}" ]; then
    echo "HERMETIC VIOLATION: SANDBOX_ROOT is unset (refusing write to $target)" >&2
    exit 1
  fi

  if [ -z "$target" ]; then
    sandbox_guard_violation "$target"
  fi

  abs_sandbox=$(cd "$SANDBOX_ROOT" && pwd -P) ||
    sandbox_guard_violation "$target" "${SANDBOX_ROOT:-unknown}"

  case "$target" in
    /*)
      current="/"
      raw_path="${target#/}"
      ;;
    *)
      current=$(pwd -P)
      raw_path="$target"
      ;;
  esac

  IFS="/" read -r -a components <<< "$raw_path"
  for component in "${components[@]}"; do
    case "$component" in
      "" | ".")
        continue
        ;;
      "..")
        if [ "$current" != "/" ]; then
          current="${current%/*}"
          [ -n "$current" ] || current="/"
        fi
        ;;
      *)
        if [ "$current" = "/" ]; then
          current="/$component"
        else
          current="$current/$component"
        fi
        ;;
    esac

    if [ -d "$current" ]; then
      resolved=$(cd "$current" && pwd -P)
      current="$resolved"
    fi
  done

  if [ -L "$current" ]; then
    sandbox_guard_violation "$target" "$abs_sandbox"
  fi

  case "$current" in
    "$abs_sandbox" | "$abs_sandbox"/*) return 0 ;;
  esac

  sandbox_guard_violation "$target" "$abs_sandbox"
}

assert_path_under_sandbox() {
  guard_write_path "$1"
}

assert_guard_allows() {
  local target="$1" msg="$2" status
  set +e
  ( guard_write_path "$target" ) >/dev/null 2>&1
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_guard_rejects() {
  local target="$1" msg="$2" status
  set +e
  ( guard_write_path "$target" ) >/dev/null 2>&1
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    fail "$msg"
  else
    pass "$msg"
  fi
}

write_sandbox_guard() {
  local guard_path="$1"
  guard_write_path "$guard_path"
  {
    declare -f sandbox_guard_violation
    declare -f guard_write_path
  } > "$guard_path"
}

# Copy the repo into a scratch dir and replace the placeholder values so the
# guard clause at the top of setup/mac.sh lets the run proceed.
make_fixture_repo() {
  local dest="$1"
  cp -R "$REPO_ROOT/." "$dest"
  rm -rf "$dest/.git"
  sed -i.bak \
    -e 's/yourname/testuser/g' \
    -e 's#/Users/yourname#/Users/testuser#g' \
    -e 's/Your Name/Test User/g' \
    -e 's/you@example\.com/test@example.com/g' \
    "$dest/flake.nix" "$dest"/nix/*.nix
  find "$dest" -name '*.bak' -delete
}

write_stub() {
  local path="$1"
  assert_path_under_sandbox "$path"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  chmod +x "$path"
}

test_sandbox_guard() {
  local root sandbox leak
  root=$(mktemp -d "${TMPDIR:-/tmp}/mac-setup-guard.XXXXXX")
  sandbox="$root/sandbox"
  leak="$root/leak"

  mkdir -p "$sandbox" "$leak"
  export SANDBOX_ROOT="$sandbox"

  assert_guard_allows "$sandbox/new/path/log" \
    "sandbox guard allows nested sandbox write"
  assert_guard_rejects "$sandbox/../leak/log" \
    "sandbox guard rejects parent traversal escape"
  ln -s "$leak/log" "$sandbox/log-link"
  assert_guard_rejects "$sandbox/log-link" \
    "sandbox guard rejects symlinked target"
  ln -s "$leak" "$sandbox/leak-link"
  assert_guard_rejects "$sandbox/leak-link/log" \
    "sandbox guard rejects symlinked parent escape"

  rm -rf "$root"
}

# Stub executables shared by both scenarios. Every one of them only ever
# records its invocation and fakes the minimum side effect setup/mac.sh
# depends on -- none of them can reach the network, the Nix store, Homebrew,
# or real root privileges.
write_shared_stubs() {
  local stub_bin="$1"

  write_stub "$stub_bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "curl $*" >> "$STUB_LOG"
url=""
for a in "$@"; do
  case "$a" in http*) url="$a" ;; esac
done
case "$url" in
  https://install.determinate.systems/nix)
    echo ": stub determinate installer payload"
    ;;
  https://install.determinate.sh/nix)
    echo "test harness: wrong determinate domain was requested: $url" >&2
    exit 1
    ;;
  *)
    echo ": stub curl payload for $url"
    ;;
esac
EOF

  write_stub "$stub_bin/sh" <<'EOF'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "sh $*" >> "$STUB_LOG"
cat >/dev/null
# Simulate what the real Determinate installer does: drop a daemon profile
# script and make a `nix` binary discoverable once that profile is sourced.
guard_write_path "$NIX_DAEMON_PROFILE"
guard_write_path "$STUB_NIX_BIN_DIR"
mkdir -p "$(dirname "$NIX_DAEMON_PROFILE")"
mkdir -p "$STUB_NIX_BIN_DIR"
guard_write_path "$STUB_NIX_BIN_DIR/nix"
cat > "$STUB_NIX_BIN_DIR/nix" <<'NIXBIN'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "nix $*" >> "$STUB_LOG"
exit 0
NIXBIN
chmod +x "$STUB_NIX_BIN_DIR/nix"
cat > "$NIX_DAEMON_PROFILE" <<PROFILE
export PATH="$STUB_NIX_BIN_DIR:\$PATH"
PROFILE
EOF

  write_stub "$stub_bin/sudo" <<'EOF'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "sudo $*" >> "$STUB_LOG"
exec "$@"
EOF

  # Only reached via PATH lookup for the nvm install line in setup/mac.sh;
  # every other bash invocation in the script uses an absolute /bin/bash.
  write_stub "$stub_bin/bash" <<'EOF'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "bash $*" >> "$STUB_LOG"
if [ -n "${NVM_DIR:-}" ]; then
  guard_write_path "$NVM_DIR/nvm.sh"
  mkdir -p "$NVM_DIR"
  cat > "$NVM_DIR/nvm.sh" <<'NVMSH'
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
nvm() {
  guard_write_path "$STUB_LOG"
  echo "nvm $*" >> "$STUB_LOG"
}
NVMSH
fi
exit 0
EOF
}

run_scenario() {
  local name="$1"
  local sandbox stub_bin fixture home_dir log startup_env_hook startup_env_sentinel
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/mac-setup-test-${name}.XXXXXX")
  if [ -z "${DEBUG_KEEP_SANDBOX:-}" ]; then
    trap 'rm -rf "$sandbox"' RETURN
  else
    echo "DEBUG: keeping sandbox $sandbox" >&2
  fi

  stub_bin="$sandbox/stub-bin"
  fixture="$sandbox/repo"
  home_dir="$sandbox/home"
  log="$sandbox/log"

  mkdir -p "$stub_bin" "$home_dir"
  export SANDBOX_ROOT="$sandbox"
  write_sandbox_guard "$sandbox/sandbox-guard.sh"
  export SANDBOX_GUARD="$sandbox/sandbox-guard.sh"
  assert_path_under_sandbox "$log"
  : > "$log"
  make_fixture_repo "$fixture"
  write_shared_stubs "$stub_bin"

  export STUB_LOG="$log"
  export STUB_NIX_BIN_DIR="$sandbox/fake-nix/var/nix/profiles/default/bin"
  export NIX_DAEMON_PROFILE="$sandbox/fake-nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  export HOME="$home_dir"
  # Re-home NVM_DIR: an inherited absolute NVM_DIR (e.g. from hm-session-vars.sh)
  # would otherwise leak writes out of the sandbox when the bash stub runs.
  export NVM_DIR="$HOME/.nvm"
  startup_env_hook="$sandbox/startup-env-hook.sh"
  startup_env_sentinel="$sandbox/startup-env-ran"
  assert_path_under_sandbox "$startup_env_hook"
  cat > "$startup_env_hook" <<HOOK
printf '%s\n' startup-env-ran >> "$startup_env_sentinel"
HOOK
  local BASH_ENV="$startup_env_hook"
  local ENV="$startup_env_hook"
  export BASH_ENV ENV

  if [ "$name" = "already-installed" ]; then
    # Simulate a machine that has already been bootstrapped once: nix and
    # darwin-rebuild are already resolvable, so the installer must not run.
    write_stub "$stub_bin/nix" <<'EOF'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "nix $*" >> "$STUB_LOG"
exit 0
EOF
    export DARWIN_REBUILD_BIN="$sandbox/current-system/sw/bin/darwin-rebuild"
    write_stub "$DARWIN_REBUILD_BIN" <<'EOF'
#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
. "${SANDBOX_GUARD:?}" || exit 1
guard_write_path "$STUB_LOG"
echo "darwin-rebuild $*" >> "$STUB_LOG"
exit 0
EOF
  else
    # Fresh machine: nix, brew, and darwin-rebuild are all absent until the
    # script itself brings nix onto PATH.
    export DARWIN_REBUILD_BIN="$sandbox/current-system/sw/bin/darwin-rebuild"
  fi

  local out status
  set +e
  out=$(env -u BASH_ENV -u ENV PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" "$REAL_BASH" "$fixture/setup/mac.sh" 2>&1)
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    fail "$name: setup/mac.sh exited $status. Output:"$'\n'"$out"
    cat "$log" >&2
    return
  fi
  pass "$name: setup/mac.sh completed in a single pass"
  if [ -e "$startup_env_sentinel" ]; then
    fail "$name: inherited shell startup env was sourced"
    return
  fi
  pass "$name: inherited shell startup env was ignored"

  local invocations
  invocations=$(cat "$log")

  if [ "$name" = "fresh-machine" ]; then
    assert_contains "$invocations" "curl --proto =https --tlsv1.2 -sSf -L https://install.determinate.systems/nix" \
      "$name: canonical Determinate URL requested" && pass "$name: canonical Determinate URL requested"
    assert_not_contains "$invocations" "install.determinate.sh" \
      "$name: wrong .sh domain never requested" && pass "$name: wrong .sh domain never requested"
    assert_contains "$invocations" "sh -s -- install" \
      "$name: installer invoked" && pass "$name: installer invoked"
    assert_line_count "$invocations" "nix .*run nix-darwin/master#darwin-rebuild -- switch" 1 \
      "$name: hardened first-activation invocation ran exactly once" && pass "$name: hardened first-activation invocation ran exactly once"
    assert_contains "$invocations" "extra-experimental-features nix-command flakes" \
      "$name: experimental features enabled for first activation" && pass "$name: experimental features enabled for first activation"
    assert_not_contains "$invocations" "darwin-rebuild switch --flake" \
      "$name: already-installed fast path not used" && pass "$name: already-installed fast path not used"
  else
    assert_not_contains "$invocations" "install.determinate" \
      "$name: installer never runs when nix is already present" && pass "$name: installer never runs when nix is already present"
    assert_line_count "$invocations" "darwin-rebuild switch --flake" 1 \
      "$name: already-installed fast path ran exactly once" && pass "$name: already-installed fast path ran exactly once"
    assert_not_contains "$invocations" "run nix-darwin/master#darwin-rebuild" \
      "$name: first-activation path not used" && pass "$name: first-activation path not used"
  fi
}

test_sandbox_guard
run_scenario "fresh-machine"
run_scenario "already-installed"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAILURES check(s) failed."
  exit 1
fi
