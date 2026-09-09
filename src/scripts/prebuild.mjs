import { fileURLToPath } from "node:url"

const library = fileURLToPath(
  new URL("../../target/rusty_v8_bridge/release/librusty_v8_bridge.link", import.meta.url),
)
const system_flags = {
  // The Darwin dylib links its own system dependencies. Repeating -lc++ here
  // produces duplicate-library warnings when Moon links blackbox tests.
  darwin: "",
  // GNU ld needs libm after the static V8 archive, even if Moon adds it earlier.
  linux: "-lstdc++ -ldl -pthread -lm",
}[process.platform]
if (system_flags === undefined) {
  throw new Error(`mizchi/v8 does not support host platform ${process.platform}`)
}

// Package-level cc-link-flags make older Moon versions try to link the library
// as an executable. Prebuild link configs also reach its tests and dependents.
process.stdout.write(JSON.stringify({
  link_configs: [{
    package: "mizchi/v8",
    link_flags: [`'${library.replaceAll("'", "'\\''")}'`, system_flags].filter(Boolean).join(" "),
  }],
}))
