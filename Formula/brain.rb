# frozen_string_literal: true

# macOS build of `brain`, the Atlas CLI (`21StarkCom/atlas`, the `@atlas/cli` package).
# node ESM — no bun-compile; the zip ships a `pnpm deploy` tree (dist + node_modules incl.
# the native modules better-sqlite3 and @lancedb/lancedb-darwin-arm64, signed (Developer ID)
# + notarized in the release zip) plus the runtime command registry at docs/specs/cli-contract/.
# The lancedb module installed in the keg carries an ad hoc signature: it is a dylib, so on
# install Homebrew rewrites its install name to the opt path and re-signs it ad hoc.
# better-sqlite3 is a bundle, which has no install name, so it keeps its Developer ID signature.
# Released from `cli-v*` tags on its own version line; the desktop app's `desktop-v*` line
# releases apart from it, so the two numbers can differ.
class Brain < Formula
  desc "Atlas CLI — the second-brain engine (ingest, index, retrieve, review)"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/atlas
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/brain-v0.34.0/brain_0.34.0_darwin_arm64.zip"
  version "0.34.0"
  sha256 "9da0fdb0fb8157aa5305c9493dc0dcdadf85b2370c660247f3ad3dff45b2dbba"

  depends_on arch: :arm64 # ships signed arm64 native modules (lancedb, better-sqlite3)
  depends_on :macos
  depends_on "node" # brain is node ESM; the keg node runs dist/bin.js

  def install
    # The zip is the runnable pnpm-deploy tree (dist/, node_modules/ with relative
    # workspace symlinks, package.json) plus docs/specs/cli-contract/ which brain reads
    # at runtime. Keep the layout intact under libexec and wrap the entry point; ATLAS_ROOT
    # pins the cli-contract root so resolution never depends on install-dir walk-up.
    libexec.install Dir["*"]
    (bin/"brain").write <<~SH
      #!/bin/bash
      export ATLAS_ROOT="#{libexec}"
      exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"
    SH
    (bin/"brain").chmod 0755
  end

  service do
    # Every 600 s, sync every registry vault. A vault whose entry sets `track` is first
    # fast-forwarded to that branch; a refused fast-forward skips that vault's sync. launchd
    # starts no second run while one is still going.
    run [opt_bin/"brain", "vaults", "sync", "--pull"]
    run_type :interval
    interval 600
    # Nobody waits on this job, so launchd may throttle its CPU and I/O.
    process_type :background
    # A LaunchAgent's default PATH lacks /opt/homebrew/bin, so brain's `git` would be /usr/bin's.
    # The wrapper runs node by its full path.
    environment_variables PATH: std_service_path_env
    # Each run appends one summary line per vault here. brain's own rotated log (`logs.dir`)
    # records each run's start and end, with timestamps.
    log_path "~/.local/state/atlas/logs/vaults-sync-service.log"
    error_log_path "~/.local/state/atlas/logs/vaults-sync-service.log"
  end

  test do
    # `brain version` prints `brain <version>`; assert it against the formula's version —
    # version-agnostic (never a hardcoded string), answered before the registry loads.
    assert_match version.to_s, shell_output("#{bin}/brain version")
  end
end
