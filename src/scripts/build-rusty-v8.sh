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
rev_file="$deps_dir/rusty_v8.rev"
rev="main"

if [[ -f "$rev_file" ]]; then
  rev="$(tr -d ' \t\r\n' < "$rev_file")"
fi

mkdir -p "$deps_dir"

if [[ ! -d "$repo_dir/.git" ]]; then
  git clone --depth 1 --branch "$rev" https://github.com/denoland/rusty_v8.git "$repo_dir"
fi

if [[ -d "$repo_dir/.git" ]]; then
  if ! git -C "$repo_dir" rev-parse --verify -q "${rev}^{commit}" >/dev/null; then
    git -C "$repo_dir" fetch --depth 1 origin "$rev" || true
  fi
  git -C "$repo_dir" checkout -q "$rev"
fi

if [[ -f "$repo_dir/.gitmodules" ]]; then
  git -C "$repo_dir" submodule update --init --depth 1 v8
fi

if [[ ! -f "$repo_dir/v8/include/v8.h" ]]; then
  echo "missing deps/rusty_v8/v8/include/v8.h" >&2
  exit 1
fi

export RUSTY_V8_MIRROR="${RUSTY_V8_MIRROR:-https://github.com/denoland/rusty_v8/releases/download}"
export CARGO_TARGET_DIR="$bridge_target_dir"

(
  cd "$bridge_dir"
  cargo build --release
)

archive="$bridge_target_dir/release/librusty_v8_bridge.a"
if [[ ! -f "$archive" ]]; then
  echo "missing $archive" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
cat > "$output" <<EOF
rusty_v8 ready
rev: $rev
archive: $archive
generated: $(date -u "+%Y-%m-%dT%H:%M:%SZ")
EOF
