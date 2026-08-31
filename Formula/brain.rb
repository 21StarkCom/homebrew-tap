require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class BrainPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private brain (atlas) tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Developer-ID-signed macOS build of `brain`, the Atlas CLI (`21StarkCom/atlas`,
# the `@atlas/cli` package). node ESM — no bun-compile; the zip ships a `pnpm deploy`
# tree (dist + node_modules incl. the signed native modules better-sqlite3 and
# @lancedb/lancedb-darwin-arm64) plus the runtime command registry at
# docs/specs/cli-contract/. Released from `cli-v*` tags (parallel to the desktop
# app's `desktop-v*`); the CLI version line is synced to the desktop app's.
class Brain < Formula
  desc "Atlas CLI — the second-brain engine (ingest, index, retrieve, review)"
  homepage "https://github.com/21StarkCom/atlas"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/atlas/releases/assets/537854160",
      using: BrainPrivateReleaseStrategy
  version "0.9.3"
  sha256 "722f5c14654edffcb19b5180d3f74126cc3423aaeb97e6ba92df1524ad3f8fb1"
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

  test do
    # `brain version` prints `brain <version>`; assert it against the formula's version —
    # version-agnostic (never a hardcoded string), answered before the registry loads.
    assert_match version.to_s, shell_output("#{bin}/brain version")
  end
end
