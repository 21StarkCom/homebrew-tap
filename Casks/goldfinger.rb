# frozen_string_literal: true

require "download_strategy"

# Cask URL specs are serialized by brew info and installed metadata. Keep the
# credential in the downloader only; inherit all native preflight/cache/resume.
class GoldfingerPrivateReleaseStrategy < CurlDownloadStrategy
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

# Signed (Developer ID) + notarized + STAPLED macOS build of goldfinger — background computer use
# for agents: Goldfinger.app runs the daemon that holds the Accessibility and Screen Recording
# grants, and its own executable is also the `goldfinger` CLI that drives it. Releases after 0.7.0
# that ship Goldfinger Control nest a second executable, the menu bar helper `goldfinger-control`,
# at Contents/Library/LoginItems/Goldfinger Control.app; it is no CLI and stays off PATH. A GUI
# app, so it ships as a cask: the .app lands in /Applications and its executable is symlinked onto
# PATH. The zip is the notarized, stapled bundle (Goldfinger.app at the archive root).
cask "goldfinger" do
  # version / asset id / sha256 are release-specific and rewritten when goldfinger's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  #
  # `brew audit` warns "Use sha256 :no_check when URL is unversioned" because the version
  # string is not in the (opaque, by-asset-id) URL. We keep a real sha256 anyway, as mimir's
  # cask does: the API asset id is the only working private fetch, and integrity stays checked.
  version "0.8.0"
  sha256 "ee618019d33b0f9f824e8bfe1b597f9dadc3051886cf509020a071715128ad80"

  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/goldfinger/releases/assets/637347441",
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

  # `brew upgrade` quits the old daemon and Goldfinger Control, its menu bar helper, then reopens
  # each running one by bundle id (`open -b`); the app serves as the new daemon. On a Mac holding
  # other copies with the daemon's id (dev builds), LaunchServices may reopen one of those instead:
  # `goldfinger stop`, and the next client starts the installed one. Dev helpers carry their own id
  # (`com.21stark.goldfinger.control.dev`). Homebrew upgrades by the installed caskfile, so an
  # upgrade from a release without the helper quits only the daemon (the caveats' `doctor --fix`).
  uninstall quit: [
    "com.21stark.goldfinger",
    "com.21stark.goldfinger.control",
  ]

  # `brew uninstall --zap` only: the socket, lock, screenshots, the snapshot epoch and every
  # recording (the trajectories and videos under Application Support/goldfinger/recordings), and
  # Goldfinger Control's login item and preferences. The helper registers itself with
  # `SMAppService.mainApp`, which owns no launchd job while it is quit and outlives its bundle
  # (goldfinger PR 124, P1), so no `launchctl:`: the zap deletes the item by its display name
  # through System Events, which asks the terminal for Automation access. The grants stay until
  # System Settings or `tccutil reset {Accessibility,ScreenCapture} <bundle id>` drops them.
  zap login_item: "Goldfinger Control",
      trash:      [
        "~/Library/Application Support/goldfinger",
        "~/Library/Caches/goldfinger",
        "~/Library/Preferences/com.21stark.goldfinger.control.plist",
      ]

  caveats <<~EOS
    Installing needs GitHub read access to 21StarkCom private repos: Homebrew's gh signed
    in (`brew install gh && gh auth login`), or export HOMEBREW_GITHUB_API_TOKEN=<token>

    Grant Goldfinger Accessibility and Screen Recording once, from a terminal:
      goldfinger setup
    It asks for each grant, opens its System Settings pane, and waits until both are allowed.
    Homebrew installs the app quarantined, so macOS may first ask whether to open Goldfinger:
    allow it, and run `goldfinger setup` again if it gave up waiting for the daemon.

    After `brew upgrade`, restart any agent running `goldfinger mcp`: until it restarts, the
    new daemon answers its calls with `version_mismatch`.

    Goldfinger Control, the menu bar app, ships in the first release after 0.7.0 that
    includes it; 0.7.0 and older have none, and these notes apply once you run such a release.
    After installing it, or upgrading to it from a release without it, run once:
      goldfinger doctor --fix
    Neither the install nor that upgrade starts Goldfinger Control (the upgrade quits only
    the daemon), so nothing registers or starts it until this does. If its icon is hidden
    (a crowded or notched menu bar, or System Settings › Menu Bar), open its panel with:
      env -i /usr/bin/open -g '#{appdir}/Goldfinger.app/Contents/Library/LoginItems/Goldfinger Control.app'

    A plain `brew uninstall` leaves Goldfinger Control registered as a login item (System
    Settings › General › Login Items & Extensions, Open at Login). Remove it there, or with
      brew uninstall --zap --cask 21StarkCom/tap/goldfinger
    which deletes it through System Events (allow your terminal's Automation access when
    macOS asks; add `--force` once a plain uninstall has run) and trashes goldfinger's
    caches, preferences and recordings.
  EOS
end
