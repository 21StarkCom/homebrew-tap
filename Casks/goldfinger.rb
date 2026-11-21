# frozen_string_literal: true

# Signed (Developer ID) + notarized + STAPLED macOS build of goldfinger — background computer use
# for agents: Goldfinger.app runs the daemon that holds the Accessibility and Screen Recording
# grants, and its own executable is also the `goldfinger` CLI that drives it. From 0.8.0 on, the
# app nests a second executable, Goldfinger Control's menu bar helper `goldfinger-control`, at
# Contents/Library/LoginItems/Goldfinger Control.app; it is no CLI and stays off PATH. A GUI
# app, so it ships as a cask: the .app lands in /Applications and its executable is symlinked onto
# PATH. The zip is the notarized, stapled bundle (Goldfinger.app at the archive root).
cask "goldfinger" do
  # version / url / sha256 are release-specific and rewritten when goldfinger's release
  # calls the bumper (the README's caller table), which publishes the zip as a release of
  # this tap — do not hand-edit them. The real sha256 keeps every download checked.
  version "0.21.0"
  sha256 "c8b56691421871cc2d41caac7ee0fef9975dcf35802a703131dbb0eae02ed008"

  # Source release repo: 21StarkCom/goldfinger
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/goldfinger-v0.21.0/Goldfinger_0.21.0_darwin_arm64.zip"
  name "Goldfinger"
  desc "Background computer use for agents: operate native apps without taking focus"
  homepage "https://github.com/21StarkCom/homebrew-tap"

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
  # recording (the trajectories and videos under Application Support/goldfinger/recordings), the
  # usage files from 0.10.0 on (Application Support/goldfinger/usage/<UTC day>/<epoch>-<k>.json,
  # the daemon's content-free counts, one file a generation and day, kept 30 days), the
  # Vision and Core ML model cache macOS compiles under the daemon's bundle id from 0.9.0 on
  # (Caches/com.21stark.goldfinger/com.apple.e5rt.e5bundlecache, shared with dev daemons), the
  # app group container of goldfinger's Safari extension from 0.13.0 on (its replies folder holds
  # the extension's answers, which can hold a page's text; dev builds share it), the extension's
  # own sandbox container (Containers/com.21stark.goldfinger.SafariExtension; a dev build's `.dev`
  # container stays), the empty Application Scripts folders macOS makes for both containers, and
  # Goldfinger Control's login item and preferences. Homebrew zaps by the list the install
  # recorded, so an install from before the tap named a container keeps it until a reinstall or an
  # upgrade. A terminal without Full Disk Access can meet `Operation not permitted` on another
  # app's sandbox container, even under sudo (homebrew/cask#201201); Homebrew then stops and asks
  # for Full Disk Access, or warns that the path "could not be trashed". The caveats say what to do.
  # The helper registers itself with `SMAppService.mainApp`, which owns no launchd job while it
  # is quit and outlives its bundle (goldfinger PR 124, P1), so no `launchctl:`: the zap deletes
  # the item by its display name through System Events, which asks the terminal for Automation
  # access. The grants stay until System Settings or
  # `tccutil reset {Accessibility,ScreenCapture} <bundle id>` drops them.
  zap login_item: "Goldfinger Control",
      trash:      [
        "~/Library/Application Scripts/com.21stark.goldfinger.SafariExtension",
        "~/Library/Application Scripts/MG9J2XF9Q3.com.21stark.goldfinger",
        "~/Library/Application Support/goldfinger",
        "~/Library/Caches/com.21stark.goldfinger",
        "~/Library/Caches/goldfinger",
        "~/Library/Containers/com.21stark.goldfinger.SafariExtension",
        "~/Library/Group Containers/MG9J2XF9Q3.com.21stark.goldfinger",
        "~/Library/Preferences/com.21stark.goldfinger.control.plist",
      ]

  caveats <<~EOS
    Grant Goldfinger Accessibility and Screen Recording once, from a terminal:
      goldfinger setup
    It asks for each grant, opens its System Settings pane, and waits until both are allowed.
    Homebrew installs the app quarantined, so macOS may first ask whether to open Goldfinger:
    allow it, and run `goldfinger setup` again if it gave up waiting for the daemon.

    After `brew upgrade`, restart any agent running `goldfinger mcp`: until it restarts, the
    new daemon answers its calls with `version_mismatch`.

    Goldfinger Control, the menu bar app, ships from 0.8.0 on; 0.7.0 and older have none.
    After installing, or upgrading from 0.7.0 or older, run once:
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
    caches, preferences, recordings and Safari extension data. If macOS refuses the
    extension's sandbox container, the zap stops with "Please enable Full Disk Access for
    your terminal" or warns that a path "could not be trashed": give your terminal Full Disk
    Access (System Settings › Privacy & Security), then run the zap again with `--force`.
  EOS
end
