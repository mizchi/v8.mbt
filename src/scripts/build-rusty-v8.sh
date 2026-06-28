#!/usr/bin/env bash
set -euo pipefail

output="${1:-}"
if [[ -z "$output" ]]; then
  echo "usage: $(basename "$0") <output-stamp>" >&2
  exit 1
fi

root_dir=$(cd "$(dirname "$0")/../.." && pwd)
deps_dir="$root_dir/deps"
repo_dir="$deps_dir/rusty_v8"
bridge_dir="$root_dir/native/bridge"
bridge_target_dir="$root_dir/target/rusty_v8_bridge"
bridge_link="$bridge_target_dir/release/librusty_v8_bridge.link"
rev_file="$deps_dir/rusty_v8.rev"
rev="main"
source_marker="$repo_dir/.mizchi-v8-source-rev"
host_os="$(uname -s)"
host_arch="$(uname -m)"

if [[ -f "$rev_file" ]]; then
  rev="$(tr -d ' \t\r\n' < "$rev_file")"
fi

mkdir -p "$deps_dir"

fetch_rusty_v8_archive() {
  local archive_url="${RUSTY_V8_SOURCE_ARCHIVE:-https://github.com/denoland/rusty_v8/archive/${rev}.tar.gz}"
  local tmp_dir
  tmp_dir=$(mktemp -d "$deps_dir/rusty_v8.XXXXXX")
  local tmp_archive="$tmp_dir/rusty_v8.tar.gz"
  local extract_dir="$tmp_dir/extract"

  mkdir -p "$extract_dir"

  echo "[mizchi/v8] fetching rusty_v8 source archive: $archive_url" >&2
  curl -L --fail --silent --show-error -o "$tmp_archive" "$archive_url"
  tar -xzf "$tmp_archive" -C "$extract_dir" --strip-components=1

  if [[ ! -f "$extract_dir/Cargo.toml" ]]; then
    echo "invalid rusty_v8 archive: missing Cargo.toml" >&2
    exit 1
  fi

  rm -rf "$repo_dir"
  mv "$extract_dir" "$repo_dir"
  git -C "$repo_dir" init -q
  git -C "$repo_dir" remote add origin https://github.com/denoland/rusty_v8.git >/dev/null 2>&1 || \
    git -C "$repo_dir" remote set-url origin https://github.com/denoland/rusty_v8.git
  printf '%s\n' "$rev" > "$source_marker"
  rm -rf "$tmp_dir"
}

source_ready=false
if [[ -d "$repo_dir/.git" ]]; then
  if [[ -f "$source_marker" ]] && [[ "$(tr -d ' \t\r\n' < "$source_marker")" == "$rev" ]]; then
    source_ready=true
  elif git -C "$repo_dir" rev-parse --verify -q "${rev}^{commit}" >/dev/null; then
    git -C "$repo_dir" checkout -q "$rev"
    printf '%s\n' "$rev" > "$source_marker"
    source_ready=true
  fi
fi

if [[ "$source_ready" != true ]]; then
  fetch_rusty_v8_archive
fi

if [[ -z "${RUSTY_V8_SRC_BINDING_PATH:-}" ]]; then
  binding_suffix=""
  case "$host_os:$host_arch" in
    Darwin:arm64 | Darwin:aarch64)
      binding_suffix="aarch64-apple-darwin"
      ;;
    Darwin:x86_64)
      binding_suffix="x86_64-apple-darwin"
      ;;
    Linux:x86_64)
      binding_suffix="x86_64-unknown-linux-gnu"
      ;;
    Linux:arm64 | Linux:aarch64)
      binding_suffix="aarch64-unknown-linux-gnu"
      ;;
  esac
  if [[ -n "$binding_suffix" ]]; then
    binding_path="$repo_dir/gen/src_binding_release_${binding_suffix}.rs"
    if [[ -f "$binding_path" ]]; then
      export RUSTY_V8_SRC_BINDING_PATH="$binding_path"
    fi
  fi
fi

export RUSTY_V8_MIRROR="${RUSTY_V8_MIRROR:-https://github.com/denoland/rusty_v8/releases/download}"
export CARGO_TARGET_DIR="$bridge_target_dir"

(
  cd "$bridge_dir"
  cargo build --release
  if [[ "$host_os" == "Darwin" ]]; then
    export RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-Wl,-undefined -C link-arg=-Wl,dynamic_lookup"
    cargo rustc --release --lib -- --crate-type cdylib
  fi
)

library="$bridge_target_dir/release/librusty_v8_bridge.a"
if [[ "$host_os" == "Darwin" ]]; then
  library="$bridge_target_dir/release/librusty_v8_bridge.dylib"
fi
if [[ ! -f "$library" ]]; then
  echo "missing $library" >&2
  exit 1
fi
ln -sf "$(basename "$library")" "$bridge_link"

mkdir -p "$(dirname "$output")"
cat > "$output" <<EOF
rusty_v8 ready
rev: $rev
library: $library
link: $bridge_link
generated: $(date -u "+%Y-%m-%dT%H:%M:%SZ")
EOF
