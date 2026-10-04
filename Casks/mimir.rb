# frozen_string_literal: true

require "download_strategy"

# Cask URL specs are serialized by brew info and installed metadata. Keep the
# credential in the downloader only; inherit all native preflight/cache/resume.
class MimirPrivateReleaseStrategy < CurlDownloadStrategy
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

# Signed (Developer ID) + notarized + STAPLED macOS build of Mímir — a personal macOS
# credential vault with a paired `mimir` CLI (ADR-0025) and a loopback MCP server for agents.
# A GUI app, so it ships as a cask: the .app lands in /Applications and the nested CLI is
# symlinked onto PATH — the same layout `make install` produces. The zip is the notarized,
# stapled bundle (Mimir.app at the archive root), so Gatekeeper validates it offline.
cask "mimir" do
  # version / asset id / sha256 are release-specific and rewritten when mimir's release
  # calls the bumper (the README's caller table) — do not hand-edit them.
  #
  # `brew audit` warns "Use sha256 :no_check when URL is unversioned" because the version
  # string is not in the (opaque, by-asset-id) URL. We keep a real sha256 anyway, DELIBERATELY:
  # `:no_check` would disable integrity verification on a private download, which is the wrong
  # trade for a credential vault, and the versioned browser-download URL 404s for private-repo
  # assets even with a token (verified) — the API asset id is the only working private fetch.
  version "0.28.0"
  sha256 "7fa3ee326af1d2336ead6688f45512d3d5c0437eab86657bb3f9815c765edf70"

  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/mimir/releases/assets/597337333",
      using: MimirPrivateReleaseStrategy
  name "Mímir"
  desc "Personal credential vault with a paired CLI and loopback MCP server"
  homepage "https://github.com/21StarkCom/mimir"

  depends_on arch: :arm64        # the shipped bundle is a signed arm64 Mach-O
  depends_on macos: :tahoe       # min macOS 26 (Package.swift .macOS(.v26)); bare symbol == ">="

  app "Mimir.app"
  # The CLI lives INSIDE the bundle and must be reached by a symlink, never a copy: it resolves
  # its own path to find the app executable it pins connections against (CLIServerPin). A copy has
  # no bundle above it and silently downgrades to unverified TCP.
  binary "#{appdir}/Mimir.app/Contents/Resources/bin/mimir"

  uninstall quit: "com.21stark.mimir"

  # `brew uninstall --zap` only. Leaves the login-Keychain vault key alone — that crypto-erases the
  # vault and is the app's own Danger Zone → Erase Everything, never a package manager's job.
  zap trash: [
    "~/Library/Application Support/.mimir-*",
    "~/Library/Application Support/Mimir",
    "~/Library/Caches/com.21stark.mimir",
    "~/Library/Preferences/com.21stark.mimir.plist",
    "~/Library/Saved Application State/com.21stark.mimir.savedState",
  ]

  caveats <<~EOS
    Installing needs GitHub read access to 21StarkCom private repos: Homebrew's gh signed
    in (`brew install gh && gh auth login`), or export HOMEBREW_GITHUB_API_TOKEN=<token>

    The `mimir` CLI talks to the running app over a local socket — open Mímir and pair
    the CLI from Settings → CLI before using it (`mimir status` reports the state).
  EOS
end
