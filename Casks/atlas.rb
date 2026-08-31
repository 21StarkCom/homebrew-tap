require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# the formulae/casks in this tap that ship the same pattern (Ruby classes share one
# namespace across the tap). Kept minimal — no Homebrew-internal GitHub API helpers.
class AtlasPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private atlas tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Developer-ID-signed + notarized macOS build of the **Atlas** desktop app — the GUI for
# the second-brain engine (the `brain` CLI is the companion formula in this tap). An Electron
# app, so it ships as a cask: Atlas.app lands in /Applications. The bundle carries its own CLI
# closure internally (a standalone Node + brain bin it spawns for status), so — unlike mimir —
# the cask exposes NO `binary`: `brain` is its own formula and must not be shadowed.
#
# Released from the source repo's `desktop-v*` tags (parallel to the CLI's `cli-v*`); the app
# is notarized (spctl: "Notarized Developer ID"). It is not offline-stapled, which is harmless
# here — `brew install --cask` strips the quarantine xattr, so Gatekeeper never gates it.
cask "atlas" do
  # version / asset id / sha256 are release-specific and rewritten by the source repo's
  # desktop bump tooling — do not hand-edit them.
  #
  # `brew audit` warns "Use sha256 :no_check when URL is unversioned" because the version is
  # not in the (opaque, by-asset-id) URL. We keep a real sha256 anyway, DELIBERATELY: :no_check
  # disables integrity verification on a private download, and the versioned browser-download URL
  # 404s for private-repo assets even with a token — the API asset id is the only working fetch.
  version "0.9.2"
  sha256 "3cecb66f12c044283f644bb3106a1d83036c70d20e53bfc75f2d503c2ba82294"

  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/atlas/releases/assets/502421943",
      using: AtlasPrivateReleaseStrategy
  name "Atlas"
  desc "Second-brain desktop app (companion GUI to the brain CLI)"
  homepage "https://github.com/21StarkCom/atlas"

  depends_on arch: :arm64          # the shipped bundle is a signed arm64 Mach-O
  depends_on macos: :monterey      # bare symbol == ">="; Electron deployment target is macOS 12

  app "Atlas.app"

  uninstall quit: "com.21stark.atlas.desktop"

  zap trash: [
    "~/Library/Application Support/Atlas",
    "~/Library/Caches/com.21stark.atlas.desktop",
    "~/Library/HTTPStorages/com.21stark.atlas.desktop",
    "~/Library/Preferences/com.21stark.atlas.desktop.plist",
    "~/Library/Saved Application State/com.21stark.atlas.desktop.savedState",
  ]

  caveats <<~EOS
    Installing needs a GitHub PAT with read access to 21StarkCom private repos:
      export HOMEBREW_GITHUB_API_TOKEN=<token>
  EOS
end
