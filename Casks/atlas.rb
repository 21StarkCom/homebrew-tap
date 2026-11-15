# frozen_string_literal: true

require "download_strategy"

# Cask URL specs are serialized by brew info and installed metadata. Keep the
# credential in the downloader only; inherit all native preflight/cache/resume.
class AtlasPrivateReleaseStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
    token = GitHub::API.credentials.to_s.strip
    if token.empty?
      raise CurlDownloadStrategyError.new(
        url,
        "This private tap needs a GitHub token with contents:read access: " \
        "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
      )
    end
    @meta[:headers] = ["Accept: application/octet-stream", "Authorization: token #{token}"]
  end
end

# Developer-ID-signed + notarized + stapled macOS build of the **Atlas** desktop app — the GUI for
# the second-brain engine (the `brain` CLI is the companion formula in this tap). An Electron
# app, so it ships as a cask: Atlas.app lands in /Applications. The bundle carries its own CLI
# closure internally (a standalone Node + brain bin it spawns for status), so — unlike mimir —
# the cask exposes NO `binary`: `brain` is its own formula and must not be shadowed.
#
# Released from the source repo's `desktop-v*` tags (parallel to the CLI's `cli-v*`). The zip is
# the notarized (spctl: "Notarized Developer ID"), stapled bundle (Atlas.app at the archive root),
# so Gatekeeper validates it offline though every install or upgrade lands it quarantined.
cask "atlas" do
  # version / asset id / sha256 are release-specific. No release step bumps this cask (the
  # README's caller table): re-point it with the bumper — do not hand-edit them.
  #
  # `brew audit` warns "Use sha256 :no_check when URL is unversioned" because the version is
  # not in the (opaque, by-asset-id) URL. We keep a real sha256 anyway, DELIBERATELY: :no_check
  # disables integrity verification on a private download, and the versioned browser-download URL
  # 404s for private-repo assets even with a token — the API asset id is the only working fetch.
  version "0.29.1"
  sha256 "b4a6d0e4b301debd318ce94485e84ca76a9f0a752a0b1b79901ac2ff9356efbb"

  # API asset URL (private repo). asset id is release-specific; re-point it with the bumper.
  url "https://api.github.com/repos/21StarkCom/atlas/releases/assets/750302366",
      using: AtlasPrivateReleaseStrategy
  name "Atlas"
  desc "Second-brain desktop app (companion GUI to the brain CLI)"
  homepage "https://github.com/21StarkCom/atlas"

  depends_on arch: :arm64 # the shipped bundle is a signed arm64 Mach-O
  # The bundled official Node (Contents/Resources/node, which runs the app's brain CLI) is built
  # for macOS 13.5, above Electron's 12.0. Homebrew floors take only a major version, so 13.0–13.4
  # still install: the app starts there, but its brain CLI does not.
  depends_on macos: :ventura # bare symbol == ">="

  app "Atlas.app"

  uninstall quit: "com.21stark.atlas.desktop"

  # `brew uninstall --zap` only. Electron names the userData folder (the app log, the pastes,
  # Chromium's storage and Crashpad) after the bundled package.json's `productName`, else its
  # `name`. Since desktop 0.11.6 that is `Atlas`, so the folder is Application Support/Atlas.
  # Builds before 0.11.6 wrote Application Support/@atlas/desktop. The first start of 0.11.6 or
  # later moves that folder to Atlas, but keeps both when Atlas already holds files, and an install
  # that has not started 0.11.6 still holds only the old one, so the zap trashes both. The
  # Config tab's Launch at login registers the app with `SMAppService.mainApp`, which outlives the
  # bundle, so the zap deletes that login item by its display name through System Events (macOS
  # asks for the terminal's Automation access).
  zap login_item: "Atlas",
      trash:      [
        "~/Library/Application Support/@atlas/desktop",
        "~/Library/Application Support/Atlas",
        "~/Library/Caches/com.21stark.atlas.desktop",
        "~/Library/HTTPStorages/com.21stark.atlas.desktop",
        "~/Library/Preferences/com.21stark.atlas.desktop.plist",
        "~/Library/Saved Application State/com.21stark.atlas.desktop.savedState",
      ],
      rmdir:      "~/Library/Application Support/@atlas"

  caveats <<~EOS
    Installing needs GitHub read access to 21StarkCom private repos: Homebrew's gh signed
    in (`brew install gh && gh auth login`), or export HOMEBREW_GITHUB_API_TOKEN=<token>
  EOS
end
