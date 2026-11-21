# frozen_string_literal: true

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
  # version / url / sha256 are release-specific. No release step bumps this cask (the README's
  # caller table): re-point it with the bumper, which publishes the zip as a release of this
  # tap — do not hand-edit them. The real sha256 keeps every download checked.
  version "0.29.5"
  sha256 "99152e9dd0b73f120501079ecef5d57dd1f1967a2a6ce071a39968da73d0583f"

  # Source release repo: 21StarkCom/atlas
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/atlas-v0.29.5/Atlas-0.29.5.zip"
  name "Atlas"
  desc "Second-brain desktop app (companion GUI to the brain CLI)"
  homepage "https://github.com/21StarkCom/homebrew-tap"

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
end
