// Resolve the installed Trajectory extension, not a username or a stale bundle hash.
// Pi expands ~/ in the MCP argument that points to this file.
const { accessSync, constants, readFileSync } = require("node:fs");
const { homedir } = require("node:os");
const { dirname, join, resolve } = require("node:path");
const { spawnSync } = require("node:child_process");

function findTrajectoryBinary(extensionDir) {
  let entries = [];
  try {
    const manifest = JSON.parse(readFileSync(join(extensionDir, "package.json"), "utf8"));
    entries = Array.isArray(manifest.pi?.extensions) ? manifest.pi.extensions : [];
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }

  // Modern installations declare their active .trajectory-bundles/<hash>/index.ts.
  // Older installations keep bin/trajectory directly under the extension directory.
  const candidates = entries
    .filter((entry) => typeof entry === "string")
    .map((entry) => join(dirname(resolve(extensionDir, entry)), "bin", "trajectory"));
  candidates.push(join(extensionDir, "bin", "trajectory"));
  for (const binary of candidates) {
    try {
      accessSync(binary, constants.X_OK);
      return binary;
    } catch (error) {
      if (error.code !== "ENOENT" && error.code !== "EACCES") throw error;
    }
  }
  throw new Error(`No executable Trajectory binary found in ${extensionDir}; install or update the Trajectory Pi extension.`);
}

if (require.main === module) {
  try {
    const binary = findTrajectoryBinary(join(homedir(), ".pi", "agent", "extensions", "trajectory"));
    const child = spawnSync(binary, ["mcp"], { stdio: "inherit" });
    if (child.error) throw child.error;
    process.exitCode = child.status ?? 1;
  } catch (error) {
    console.error(`trajectory-mcp: ${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = { findTrajectoryBinary };
