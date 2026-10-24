# frozen_string_literal: true

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
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/atlas/releases/assets/672619852",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.12.0"
  sha256 "5fdc9be491832d84ae01332e31a4d34af4a8b214c3b657fe4d4d27b95579c138"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

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
    # Every 600 s, fast-forward each registry vault whose entry sets `track`, then sync every
    # registry vault. launchd starts no second run while one is still going.
    run [opt_bin/"brain", "vaults", "sync", "--pull"]
    run_type :interval
    interval 600
    # A LaunchAgent's default PATH lacks /opt/homebrew/bin, where git and node live.
    environment_variables PATH: std_service_path_env
    log_path "~/.local/state/atlas/logs/vaults-sync-service.log"
    error_log_path "~/.local/state/atlas/logs/vaults-sync-service.log"
  end

  test do
    # `brain version` prints `brain <version>`; assert it against the formula's version —
    # version-agnostic (never a hardcoded string), answered before the registry loads.
    assert_match version.to_s, shell_output("#{bin}/brain version")
  end
end
