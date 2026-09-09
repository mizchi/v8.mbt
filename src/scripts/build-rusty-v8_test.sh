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
  if ! grep -Fq -e "$pattern" "$file"; then
    echo "--- $file" >&2
    cat "$file" >&2
    fail "expected '$file' to contain '$pattern'"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  if [[ -f "$file" ]] && grep -Fq -e "$pattern" "$file"; then
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

  # Mirrors the artifact placement real cargo uses: `cargo build` uplifts the
  # crate types declared in Cargo.toml into `release/`, and `cargo rustc` only
  # uplifts an extra crate type when `--crate-type` is cargo's own flag. Passed
  # through to rustc after `--`, the artifact is left in `release/deps/` under a
  # metadata-suffixed name, which is what silently broke the Darwin bridge.
  cat > "$bin_dir/cargo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${FAKE_LOG_DIR}/cargo.log"
echo "${RUSTFLAGS:-}" >> "${FAKE_LOG_DIR}/rustflags.log"
mkdir -p "${CARGO_TARGET_DIR}/release/deps"

crate_type=""
passthrough=false
uplift=false
for arg in "$@"; do
  case "$arg" in
    --)
      passthrough=true
      ;;
    --crate-type)
      crate_type="pending"
      if [[ "$passthrough" == false ]]; then
        uplift=true
      fi
      ;;
    *)
      if [[ "$crate_type" == "pending" ]]; then
        crate_type="$arg"
      fi
      ;;
  esac
done

if [[ "$crate_type" == "cdylib" ]]; then
  printf 'fake dylib\n' > "${CARGO_TARGET_DIR}/release/deps/librusty_v8_bridge-0123456789abcdef.dylib"
  if [[ "$uplift" == true ]]; then
    printf 'fake dylib\n' > "${CARGO_TARGET_DIR}/release/librusty_v8_bridge.dylib"
  fi
else
  printf 'fake archive\n' > "${CARGO_TARGET_DIR}/release/librusty_v8_bridge.a"
fi
SH
  chmod +x "$bin_dir/cargo"

  cat > "$bin_dir/uname" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  -s) echo "${FAKE_UNAME_S:-Linux}" ;;
  -m) echo "${FAKE_UNAME_M:-x86_64}" ;;
  *) echo "${FAKE_UNAME_S:-Linux}" ;;
esac
SH
  chmod +x "$bin_dir/uname"
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

test_build_uplifts_darwin_cdylib() {
  local root="$tmp_root/build-darwin"
  local fake_bin="$root/fake-bin"
  local log_dir="$root/logs"
  make_fixture_root "$root"
  mkdir -p "$log_dir"
  make_fake_path "$fake_bin"

  FAKE_LOG_DIR="$log_dir" FAKE_UNAME_S=Darwin FAKE_UNAME_M=arm64 \
    PATH="$fake_bin:$PATH" bash "$root/src/scripts/build-rusty-v8.sh" \
    "$root/out/rusty_v8.stamp"

  local release_dir="$root/target/rusty_v8_bridge/release"
  # The cdylib has to be uplifted into `release/`; leaving it in `release/deps/`
  # is what the `-- --crate-type cdylib` passthrough did, and the link flags in
  # `src/moon.pkg` cannot see it there.
  [[ -f "$release_dir/librusty_v8_bridge.dylib" ]] ||
    fail "darwin build did not uplift librusty_v8_bridge.dylib into release/"
  [[ -L "$release_dir/librusty_v8_bridge.link" ]] ||
    fail "darwin build did not write stable bridge link"
  [[ "$(readlink "$release_dir/librusty_v8_bridge.link")" == "librusty_v8_bridge.dylib" ]] ||
    fail "darwin bridge link does not point at the dylib"
  assert_file_contains "$log_dir/cargo.log" "rustc --release --lib --crate-type cdylib"
  assert_file_not_contains "$log_dir/cargo.log" "-- --crate-type cdylib"
  assert_file_contains "$log_dir/rustflags.log" "-C link-arg=-lc++"
  assert_file_contains "$log_dir/rustflags.log" "-C link-arg=-framework -C link-arg=CoreFoundation"
}

test_postadd_respects_skip_env
test_build_fetches_rusty_v8_archive_without_git_clone
test_build_uplifts_darwin_cdylib

echo "script tests passed"
