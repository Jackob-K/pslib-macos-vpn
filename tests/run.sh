#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/pslib-vpn"
MOCK_SOURCE="$ROOT/tests/mocks/mock-command"
TEST_ROOT="$(mktemp -d -t pslib-vpn-tests.XXXXXX)"
PASS=0
FAIL=0

cleanup() {
  if [[ "${PSLIB_KEEP_TEST_TMP:-0}" -eq 1 ]]; then
    printf 'Testovaci data zustala v: %s\n' "$TEST_ROOT"
  else
    rm -rf "$TEST_ROOT"
  fi
}
trap cleanup EXIT

ok() { printf 'OK  %s\n' "$1"; PASS=$((PASS + 1)); }
not_ok() { printf 'FAIL %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

assert_contains() {
  local file="$1" expected="$2"
  grep -Fq -- "$expected" "$file"
}

assert_not_contains() {
  local file="$1" unexpected="$2"
  ! grep -Fq -- "$unexpected" "$file"
}

new_env() {
  local name="$1" command
  CASE_DIR="$TEST_ROOT/$name"
  MOCK_BIN="$CASE_DIR/bin"
  export MOCK_DIR="$CASE_DIR/state"
  export MOCK_LOG="$CASE_DIR/log"
  export MOCK_BREW_PREFIX="$CASE_DIR/brew"
  export PSLIB_CONFIG_DIR="$CASE_DIR/config"
  export PSLIB_RUNTIME_DIR="$CASE_DIR/config/run"
  export PSLIB_SSTPC_BIN="$MOCK_BIN/sstpc"
  export PSLIB_PPPD_BIN="$MOCK_BIN/pppd"
  export PSLIB_MOUNT_WAIT_ATTEMPTS=2
  export PSLIB_MOUNT_WAIT_SECONDS=0.01
  export PSLIB_VPN_WAIT_ATTEMPTS=20
  export PSLIB_VPN_WAIT_SECONDS=0.01
  export MOCK_SECRET_SENTINEL="mock-secret"
  unset MOCK_ACTIVE MOCK_FAIL_W MOCK_NO_INTERFACE MOCK_PPPD_EXIT MOCK_PPPD_SLEEP MOCK_DISKUTIL_FAIL

  mkdir -p "$MOCK_BIN" "$MOCK_DIR" "$MOCK_LOG" \
    "$MOCK_BREW_PREFIX/etc/ca-certificates"
  : >"$MOCK_BREW_PREFIX/etc/ca-certificates/cert.pem"
  : >"$MOCK_DIR/mounts"
  for command in security sudo pppd sstpc brew ifconfig route pgrep pkill \
    mount open diskutil umount nc; do
    ln -s "$MOCK_SOURCE" "$MOCK_BIN/$command"
  done
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
}

configure_default() {
  printf 'student@pslib.cz\nmock-secret\n\n\n' | "$CLI" setup >"$CASE_DIR/setup.out" 2>&1
}

test_setup_and_secure_connect() {
  new_env secure-connect
  configure_default
  "$CLI" connect >"$CASE_DIR/connect.out" 2>&1
  assert_contains "$PSLIB_CONFIG_DIR/settings" 'DISKS=S,X'
  assert_contains "$MOCK_LOG/commands.log" '<file> </dev/stdin>'
  assert_contains "$MOCK_LOG/commands.log" '--nolaunchpppd'
  assert_contains "$MOCK_LOG/commands.log" 'sstpc <--nolaunchpppd>'
  assert_contains "$MOCK_LOG/commands.log" 'athena.ad.pslib.cz/doma$/student'
  assert_not_contains "$MOCK_LOG/commands.log" 'mock-secret'
  [[ -e "$MOCK_DIR/password-received-on-stdin" ]]
  [[ ! -e "$PSLIB_RUNTIME_DIR/mounted-volumes" ]]
}

test_missing_keychain() {
  new_env missing-keychain
  mkdir -p "$PSLIB_CONFIG_DIR"
  printf 'student@pslib.cz\n' >"$PSLIB_CONFIG_DIR/username"
  printf 'DISKS=S,X\nX_HOME=student\n' >"$PSLIB_CONFIG_DIR/settings"
  if "$CLI" connect >"$CASE_DIR/out" 2>&1; then return 1; fi
  assert_contains "$CASE_DIR/out" 'VPN heslo neni v Keychainu'
}

test_bad_password() {
  new_env bad-password
  configure_default
  export MOCK_PPPD_EXIT=19
  if "$CLI" connect >"$CASE_DIR/out" 2>&1; then return 1; fi
  assert_contains "$CASE_DIR/out" 'Server odmitl prihlaseni'
  assert_not_contains "$CASE_DIR/out" 'mock-secret'
  [[ ! -d "$PSLIB_RUNTIME_DIR/connect.lock" ]]
}

test_already_active() {
  new_env already-active
  configure_default
  export MOCK_ACTIVE=1
  if "$CLI" connect >"$CASE_DIR/out" 2>&1; then return 1; fi
  assert_contains "$CASE_DIR/out" 'VPN uz bezi'
}

test_interrupted_connect() {
  new_env interrupted
  configure_default
  export MOCK_NO_INTERFACE=1 MOCK_PPPD_SLEEP=1
  "$CLI" connect >"$CASE_DIR/out" 2>&1 &
  local pid=$!
  /bin/sleep 0.1
  kill -HUP "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  [[ ! -d "$PSLIB_RUNTIME_DIR/connect.lock" ]]
  assert_contains "$MOCK_LOG/commands.log" 'pkill'
}

test_unavailable_smb_does_not_fail_vpn() {
  new_env smb-failure
  configure_default
  printf 'DISKS=W\nX_HOME=student\n' >"$PSLIB_CONFIG_DIR/settings"
  export MOCK_FAIL_W=1
  "$CLI" connect >"$CASE_DIR/out" 2>&1
  assert_contains "$CASE_DIR/out" 'Selhaly: W'
  assert_contains "$CASE_DIR/out" 'VPN zustava pripojena'
}

test_disconnect_only_managed_mounts() {
  new_env selective-disconnect
  mkdir -p "$PSLIB_RUNTIME_DIR"
  printf 'S|/Volumes/S\n' >"$PSLIB_RUNTIME_DIR/mounted-volumes"
  {
    printf '//mock@athena.ad.pslib.cz/public on /Volumes/S (smbfs, nodev)\n'
    printf '//mock@athena.ad.pslib.cz/doma$ on /Volumes/X (smbfs, nodev)\n'
  } >"$MOCK_DIR/mounts"
  export MOCK_DISKUTIL_FAIL=1
  "$CLI" disconnect >"$CASE_DIR/out" 2>&1
  assert_contains "$MOCK_DIR/mounts" '/Volumes/X'
  assert_not_contains "$MOCK_DIR/mounts" '/Volumes/S'
  assert_contains "$MOCK_LOG/commands.log" 'umount </Volumes/S>'
}

test_forget_requires_confirmation() {
  new_env forget
  configure_default
  printf 'n\n' | "$CLI" forget-credentials >"$CASE_DIR/no.out" 2>&1
  [[ -e "$MOCK_DIR/keychain" ]]
  printf 'ano\n' | "$CLI" forget-credentials >"$CASE_DIR/yes.out" 2>&1
  [[ ! -e "$MOCK_DIR/keychain" ]]
}

run_test() {
  local name="$1" fn="$2" rc
  set +e
  ( set -e; "$fn" )
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then ok "$name"; else not_ok "$name"; fi
}

run_test "setup a heslo pouze na stdin pppd" test_setup_and_secure_connect
run_test "chybejici zaznam v Keychainu" test_missing_keychain
run_test "chybne heslo" test_bad_password
run_test "jiz aktivni VPN" test_already_active
run_test "prerusene pripojovani uklidi stav" test_interrupted_connect
run_test "nedostupny SMB disk neukonci VPN" test_unavailable_smb_does_not_fail_vpn
run_test "disconnect odpoji jen spravovany svazek" test_disconnect_only_managed_mounts
run_test "zapomenuti udaju vyzaduje potvrzeni" test_forget_requires_confirmation

printf '\nVysledek: %s OK, %s chyb\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
