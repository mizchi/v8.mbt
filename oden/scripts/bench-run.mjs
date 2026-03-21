import fs from "node:fs"
import path from "node:path"
import process from "node:process"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const moduleRoot = path.resolve(scriptDir, "..")
const fixtureDir = path.join(moduleRoot, "bench", "fixtures", "run_sync")
const resultsDir = path.join(moduleRoot, ".oden", "bench")
const binaryPath = path.join(
  moduleRoot,
  "_build",
  "native",
  "release",
  "build",
  "cmd",
  "oden",
  "oden.exe",
)
const snapshotPath = path.join(
  fixtureDir,
  ".oden",
  "run",
  "oden-run.snapshot.bin",
)
const hotResultPath = path.join(resultsDir, "run-sync-hot.json")
const coldSnapshotResultPath = path.join(
  resultsDir,
  "run-sync-cold-snapshot.json",
)

function runOrThrow(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, {
    cwd: moduleRoot,
    stdio: "inherit",
    ...options,
  })
  if (result.status !== 0) {
    process.exit(result.status ?? 1)
  }
}

function benchmarkResult(jsonPath) {
  const report = JSON.parse(fs.readFileSync(jsonPath, "utf8"))
  return report.results[0]
}

fs.mkdirSync(resultsDir, { recursive: true })

runOrThrow("moon", ["build", "src/cmd/oden", "--target", "native", "--release"])

if (!fs.existsSync(binaryPath)) {
  throw new Error(`oden binary not found: ${binaryPath}`)
}

runOrThrow(binaryPath, ["run"], { cwd: fixtureDir, stdio: "ignore" })

runOrThrow(
  "hyperfine",
  [
    "--warmup",
    "1",
    "--runs",
    "10",
    "--export-json",
    hotResultPath,
    `${binaryPath} run`,
  ],
  { cwd: fixtureDir },
)

runOrThrow(
  "hyperfine",
  [
    "--warmup",
    "1",
    "--runs",
    "10",
    "--prepare",
    "rm -f .oden/run/oden-run.snapshot.bin",
    "--export-json",
    coldSnapshotResultPath,
    `${binaryPath} run`,
  ],
  { cwd: fixtureDir },
)

const hot = benchmarkResult(hotResultPath)
const coldSnapshot = benchmarkResult(coldSnapshotResultPath)
const deltaMs = (coldSnapshot.mean - hot.mean) * 1000
const ratio = hot.mean > 0 ? coldSnapshot.mean / hot.mean : 0

console.log("[oden bench] fixture:", fixtureDir)
console.log(
  `[oden bench] hot mean: ${(hot.mean * 1000).toFixed(2)} ms (${hot.min.toFixed(4)}s min)`,
)
console.log(
  `[oden bench] cold-snapshot mean: ${(coldSnapshot.mean * 1000).toFixed(2)} ms`,
)
console.log(
  `[oden bench] cold/hot ratio: ${ratio.toFixed(2)}x, delta: ${deltaMs.toFixed(2)} ms`,
)
