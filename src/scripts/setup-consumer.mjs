import fs from "node:fs"
import path from "node:path"
import process from "node:process"
import { fileURLToPath } from "node:url"

const script_dir = path.dirname(fileURLToPath(import.meta.url))
const v8_root = path.resolve(script_dir, "..", "..")
const example_prebuild_path = path.join(
  v8_root,
  "docs",
  "examples",
  "mizchi-v8-consumer-prebuild.mjs",
)
const build_var = "${build.MIZCHI_V8_CC_LINK_FLAGS}"

function parse_args(argv) {
  let module_root = process.cwd()
  let main_pkg = null
  let allow_create_main = false
  for (let i = 0; i < argv.length; i = i + 1) {
    const arg = argv[i]
    if (arg === "--module-root") {
      i = i + 1
      module_root = path.resolve(argv[i] ?? "")
    } else if (arg === "--main-pkg") {
      i = i + 1
      main_pkg = argv[i] ?? ""
    } else if (arg === "--allow-create-main") {
      allow_create_main = true
    } else if (arg === "--help" || arg === "-h") {
      print_help()
      process.exit(0)
    } else {
      throw new Error(`unknown argument: ${arg}`)
    }
  }
  return { module_root, main_pkg, allow_create_main }
}

function print_help() {
  console.log(
    [
      "Usage: node src/scripts/setup-consumer.mjs [options]",
      "",
      "Options:",
      "  --module-root <dir>   Consumer module root. Defaults to cwd.",
      "  --main-pkg <path>     Main package moon.pkg path, relative to module root.",
      "  --allow-create-main   Create the main package file if it does not exist.",
    ].join("\n"),
  )
}

function read_json(file_path) {
  return JSON.parse(fs.readFileSync(file_path, "utf8"))
}

function write_json(file_path, value) {
  fs.writeFileSync(file_path, `${JSON.stringify(value, null, 2)}\n`)
}

function ensure_example_script(module_root) {
  const scripts_dir = path.join(module_root, "scripts")
  const consumer_prebuild_path = path.join(
    scripts_dir,
    "mizchi-v8-consumer-prebuild.mjs",
  )
  fs.mkdirSync(scripts_dir, { recursive: true })
  fs.copyFileSync(example_prebuild_path, consumer_prebuild_path)
  return path.relative(module_root, consumer_prebuild_path)
}

function update_moon_mod(module_root, prebuild_rel_path) {
  const moon_mod_path = path.join(module_root, "moon.mod.json")
  const moon_mod = read_json(moon_mod_path)
  const current = moon_mod["--moonbit-unstable-prebuild"]
  if (
    typeof current === "string" &&
    current !== "" &&
    current !== prebuild_rel_path
  ) {
    throw new Error(
      `moon.mod.json already has --moonbit-unstable-prebuild=${current}; update it manually`,
    )
  }
  moon_mod["--moonbit-unstable-prebuild"] = prebuild_rel_path
  write_json(moon_mod_path, moon_mod)
}

function detect_main_pkg(module_root) {
  const candidates = [
    "cmd/main/moon.pkg",
    "app/main/moon.pkg",
    "moon.pkg",
  ]
  for (const candidate of candidates) {
    if (fs.existsSync(path.join(module_root, candidate))) {
      return candidate
    }
  }
  return "cmd/main/moon.pkg"
}

function ensure_link_block(text) {
  if (text.includes(build_var)) {
    return text
  }

  if (/"cc-link-flags"\s*:\s*"/.test(text)) {
    return text.replace(
      /"cc-link-flags"\s*:\s*"([^"]*)"/,
      (_whole, flags) => {
        const merged = `${build_var} ${flags}`.trim()
        return `"cc-link-flags": "${merged}"`
      },
    )
  }

  if (/"native"\s*:\s*\{/.test(text)) {
    return text.replace(
      /("native"\s*:\s*\{\n)/,
      `$1      "cc-link-flags": "${build_var}",\n`,
    )
  }

  if (/link\s*:\s*\{/.test(text)) {
    return text.replace(
      /(link\s*:\s*\{\n)/,
      `$1    "native": {\n      "cc-link-flags": "${build_var}",\n    },\n`,
    )
  }

  const link_block =
    `  link: {\n` +
    `    "native": {\n` +
    `      "cc-link-flags": "${build_var}",\n` +
    `    },\n` +
    `  },\n`

  if (/options\s*\(/.test(text)) {
    return text.replace(/options\s*\(\n/, (whole) => `${whole}${link_block}`)
  }

  return `${text.trimEnd()}\n\noptions(\n${link_block})\n`
}

function ensure_supported_targets(text) {
  if (/"supported-targets"\s*:\s*"native"/.test(text)) {
    return text
  }
  if (/options\s*\(/.test(text)) {
    return text.replace(
      /\n\)\s*$/,
      `\n  "supported-targets": "native",\n)\n`,
    )
  }
  return `${text.trimEnd()}\n\noptions(\n  "supported-targets": "native",\n)\n`
}

function update_main_pkg(module_root, main_pkg_rel_path, allow_create_main) {
  const main_pkg_path = path.join(module_root, main_pkg_rel_path)
  if (!fs.existsSync(main_pkg_path)) {
    if (!allow_create_main) {
      throw new Error(
        `main package file not found: ${main_pkg_rel_path} (pass --allow-create-main to create it)`,
      )
    }
    fs.mkdirSync(path.dirname(main_pkg_path), { recursive: true })
    fs.writeFileSync(
      main_pkg_path,
      [
        "options(",
        '  "is-main": true,',
        ")",
        "",
      ].join("\n"),
    )
  }

  let text = fs.readFileSync(main_pkg_path, "utf8")
  text = ensure_link_block(text)
  text = ensure_supported_targets(text)
  fs.writeFileSync(main_pkg_path, text)
}

const args = parse_args(process.argv.slice(2))
const main_pkg_rel_path = args.main_pkg ?? detect_main_pkg(args.module_root)
const prebuild_rel_path = ensure_example_script(args.module_root)
update_moon_mod(args.module_root, prebuild_rel_path)
update_main_pkg(args.module_root, main_pkg_rel_path, args.allow_create_main)

console.error(`[mizchi/v8] wrote ${prebuild_rel_path}`)
console.error(`[mizchi/v8] updated moon.mod.json`)
console.error(`[mizchi/v8] updated ${main_pkg_rel_path}`)
