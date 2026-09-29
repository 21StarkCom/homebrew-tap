# frozen_string_literal: true

require "download_strategy"

# Cask URL specs are serialized by brew info and installed metadata. Keep the
# credential in the downloader only; inherit all native preflight/cache/resume.
class GoldfingerPrivateReleaseStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
    if token.empty?
      raise CurlDownloadStrategyError.new(
        url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
      )
    end
    @meta[:headers] = ["Accept: application/octet-stream", "Authorization: token #{token}"]
  end
end

# Signed (Developer ID) + notarized + STAPLED macOS build of goldfinger — background computer use
# for agents: Goldfinger.app runs the daemon that holds the Accessibility and Screen Recording
# grants, and its one executable is also the `goldfinger` CLI that drives it. A GUI app, so it
# ships as a cask: the .app lands in /Applications and its executable is symlinked onto PATH. The
# zip is the notarized, stapled bundle (Goldfinger.app at the archive root).
cask "goldfinger" do
  # version / asset id / sha256 are release-specific and rewritten when goldfinger's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  #
  # `brew audit` warns "Use sha256 :no_check when URL is unversioned" because the version
  # string is not in the (opaque, by-asset-id) URL. We keep a real sha256 anyway, as mimir's
  # cask does: the API asset id is the only working private fetch, and integrity stays checked.
  version "0.3.0"
  sha256 "f0fb3fc85a6c1709ed069ad091e54c2207bb1a081d97661ceaf03470e2bb293f"

  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/goldfinger/releases/assets/597154611",
      using: GoldfingerPrivateReleaseStrategy
  name "Goldfinger"
  desc "Background computer use for agents: operate native apps without taking focus"
  homepage "https://github.com/21StarkCom/goldfinger"

  depends_on arch: :arm64        # the shipped bundle is a signed arm64 Mach-O
  depends_on macos: :tahoe       # min macOS 26 (Package.swift .macOS(.v26)); bare symbol == ">="

  app "Goldfinger.app"
  # A symlink, never a copy: a client that finds no daemon starts one from the app containing its
  # own binary, found from the realpath of the executable. A copy has no bundle above it and can
  # start nothing.
  binary "#{appdir}/Goldfinger.app/Contents/MacOS/goldfinger"

  # `brew upgrade` quits the old daemon, then reopens the app by bundle id (`open -b`), which serves
  # as the new daemon. On a Mac holding other copies with this id (dev builds), LaunchServices may
  # reopen one of those instead: `goldfinger stop`, and the next client starts the installed one.
  uninstall quit: "com.21stark.goldfinger"

  # `brew uninstall --zap` only: the socket, lock, screenshots, the snapshot epoch and every
  # recording (the trajectories and videos under Application Support/goldfinger/recordings). The grants
  # stay until System Settings or `tccutil reset {Accessibility,ScreenCapture} <bundle id>` drops them.
  zap trash: [
    "~/Library/Application Support/goldfinger",
    "~/Library/Caches/goldfinger",
  ]

  caveats <<~EOS
    Installing needs a GitHub PAT with read access to 21StarkCom private repos:
      export HOMEBREW_GITHUB_API_TOKEN=<token>

    Grant Goldfinger Accessibility and Screen Recording once, from a terminal:
      goldfinger setup
    It asks for each grant, opens its System Settings pane, and waits until both are allowed.
    Homebrew installs the app quarantined, so macOS may first ask whether to open Goldfinger:
    allow it, and run `goldfinger setup` again if it gave up waiting for the daemon.

    Before `brew upgrade` or `brew uninstall`, run `goldfinger stop`: quitting the app ends a
    `record start --video` recording without finishing its video.mp4.
    After `brew upgrade`, restart any agent running `goldfinger mcp`: until it restarts, the
    new daemon answers its calls with `version_mismatch`.
  EOS
end
