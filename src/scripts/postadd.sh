#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/../.." && pwd)
stamp_path="$root_dir/src/build-stamps/rusty_v8_build.stamp"

env_truthy() {
  local value="${!1:-}"
  case "$value" in
    "" | 0 | false | FALSE | False | no | NO | No | off | OFF | Off)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

skip_reason=""
if env_truthy MIZCHI_V8_OPTIONAL; then
  skip_reason="MIZCHI_V8_OPTIONAL"
elif env_truthy CRATER_SKIP_V8_BUILD; then
  skip_reason="CRATER_SKIP_V8_BUILD"
fi

if [[ -n "$skip_reason" ]]; then
  echo "[mizchi/v8] skipping native bridge build via $skip_reason" >&2
  mkdir -p "$(dirname "$stamp_path")"
  cat > "$stamp_path" <<EOF
rusty_v8 skipped
reason: $skip_reason
generated: $(date -u "+%Y-%m-%dT%H:%M:%SZ")
EOF
  exit 0
fi

echo "[mizchi/v8] building native bridge via postadd hook" >&2
bash "$root_dir/src/scripts/build-rusty-v8.sh" "$stamp_path"
echo "[mizchi/v8] consumer setup helper: node .mooncakes/mizchi/v8/src/scripts/setup-consumer.mjs --main-pkg cmd/main/moon.pkg" >&2
