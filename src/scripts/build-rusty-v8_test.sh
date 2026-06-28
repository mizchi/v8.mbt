#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
tmp_root="${TMPDIR:-/tmp}/v8-mbt-script-test.$$"

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$file"; then
    echo "--- $file" >&2
    cat "$file" >&2
    fail "expected '$file' to contain '$pattern'"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  if [[ -f "$file" ]] && grep -Fq "$pattern" "$file"; then
    echo "--- $file" >&2
    cat "$file" >&2
    fail "expected '$file' not to contain '$pattern'"
  fi
}

make_fixture_root() {
  local root="$1"
  mkdir -p "$root/src/scripts" "$root/deps" "$root/native/bridge/src"
  cp "$repo_root/src/scripts/postadd.sh" "$root/src/scripts/postadd.sh"
  cp "$repo_root/src/scripts/build-rusty-v8.sh" "$root/src/scripts/build-rusty-v8.sh"
  printf 'v146.8.0\n' > "$root/deps/rusty_v8.rev"
  printf '[package]\nname = "bridge"\n' > "$root/native/bridge/Cargo.toml"
  printf 'pub fn bridge() {}\n' > "$root/native/bridge/src/lib.rs"
}

make_fake_path() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${FAKE_LOG_DIR}/git.log"
if [[ "${1:-}" == "clone" ]]; then
  echo "git clone must not be used" >&2
  exit 42
fi
if [[ "${1:-}" == "-C" ]]; then
  cd "$2"
  shift 2
fi
case "${1:-}" in
  init)
    mkdir -p .git
    ;;
  remote)
    ;;
esac
SH
  chmod +x "$bin_dir/git"

  cat > "$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
out=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
echo "$url" >> "${FAKE_LOG_DIR}/curl.log"
[[ -n "$out" ]] || exit 2
printf 'fake archive for %s\n' "$url" > "$out"
SH
  chmod +x "$bin_dir/curl"

  cat > "$bin_dir/tar" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
dest=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      dest="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$dest" ]] || exit 2
mkdir -p "$dest/src" "$dest/gen"
printf '[package]\nname = "v8"\nversion = "146.8.0"\n' > "$dest/Cargo.toml"
printf 'include!(env!("RUSTY_V8_SRC_BINDING_PATH"));\n' > "$dest/src/binding.rs"
printf 'fake binding\n' > "$dest/gen/src_binding_release_aarch64-apple-darwin.rs"
SH
  chmod +x "$bin_dir/tar"

  cat > "$bin_dir/cargo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${FAKE_LOG_DIR}/cargo.log"
mkdir -p "${CARGO_TARGET_DIR}/release"
printf 'fake archive\n' > "${CARGO_TARGET_DIR}/release/librusty_v8_bridge.a"
printf 'fake dylib\n' > "${CARGO_TARGET_DIR}/release/librusty_v8_bridge.dylib"
SH
  chmod +x "$bin_dir/cargo"
}

test_postadd_respects_skip_env() {
  local root="$tmp_root/postadd"
  make_fixture_root "$root"
  cat > "$root/src/scripts/build-rusty-v8.sh" <<'SH'
#!/usr/bin/env bash
echo "build script should not be called" >&2
exit 47
SH
  chmod +x "$root/src/scripts/build-rusty-v8.sh"

  MIZCHI_V8_OPTIONAL=1 bash "$root/src/scripts/postadd.sh"
  local stamp="$root/src/build-stamps/rusty_v8_build.stamp"
  [[ -f "$stamp" ]] || fail "postadd skip did not write stamp"
  assert_file_contains "$stamp" "rusty_v8 skipped"
  assert_file_contains "$stamp" "MIZCHI_V8_OPTIONAL"

  rm -f "$stamp"
  CRATER_SKIP_V8_BUILD=1 bash "$root/src/scripts/postadd.sh"
  [[ -f "$stamp" ]] || fail "postadd crater skip did not write stamp"
  assert_file_contains "$stamp" "rusty_v8 skipped"
  assert_file_contains "$stamp" "CRATER_SKIP_V8_BUILD"
}

test_build_fetches_rusty_v8_archive_without_git_clone() {
  local root="$tmp_root/build"
  local fake_bin="$root/fake-bin"
  local log_dir="$root/logs"
  make_fixture_root "$root"
  mkdir -p "$log_dir"
  make_fake_path "$fake_bin"

  FAKE_LOG_DIR="$log_dir" PATH="$fake_bin:$PATH" bash "$root/src/scripts/build-rusty-v8.sh" "$root/out/rusty_v8.stamp"

  [[ -f "$root/out/rusty_v8.stamp" ]] || fail "build did not write stamp"
  assert_file_contains "$root/out/rusty_v8.stamp" "rusty_v8 ready"
  assert_file_contains "$root/out/rusty_v8.stamp" "link:"
  [[ -L "$root/target/rusty_v8_bridge/release/librusty_v8_bridge.link" ]] || fail "build did not write stable bridge link"
  assert_file_contains "$log_dir/curl.log" "https://github.com/denoland/rusty_v8/archive/v146.8.0.tar.gz"
  assert_file_contains "$log_dir/git.log" "init"
  assert_file_not_contains "$log_dir/git.log" "clone"
}

test_postadd_respects_skip_env
test_build_fetches_rusty_v8_archive_without_git_clone

echo "script tests passed"
