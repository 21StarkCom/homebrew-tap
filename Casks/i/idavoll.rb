# frozen_string_literal: true

# idavoll, the 21Stark workspace installer: Idavoll.app and its `idavoll` CLI. The cask
# installs the release's own Developer ID signed, notarized and stapled .pkg, the package
# a bare Mac installs from the GitHub release: /Applications/Idavoll.app and
# /usr/local/bin/idavoll, owned by root. So the install and each upgrade ask for the sudo
# password, as `sudo installer` does. A bare Mac has no Homebrew yet (idavoll installs
# it), so it still takes the .pkg from the release.
#
# This file is in Casks/i/, not in Casks/. idavoll's Fleet CLIs step (0.10.0 and older)
# installs each Casks/*.rb of this tap, so it would install idavoll's own .pkg in the
# middle of its own run, and the package's preinstall quits a running Idavoll.app.
# Homebrew reads Casks/**/*.rb; idavoll reads Casks/*.rb only. The GetEvinced mirror copies
# this cask to the same path in GetEvinced/tap, .pkg included: the operator accepted the
# app's readable JavaScript there on 2026-10-31.
cask "idavoll" do
  # version / url / sha256 are release-specific and rewritten when idavoll's release calls
  # the bumper (the README's caller table), which publishes the .pkg as a release of this
  # tap — do not hand-edit them.
  version "0.22.0"
  sha256 "eaebf754ce33958d9898e5f017e5c1da9628299de7b72f2e49c6916fdf47a34c"

  # The download keeps the asset's own name (idavoll-<version>.pkg), which `pkg` names.
  # Source release repo: 21StarkCom/idavoll
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/idavoll-v0.22.0/idavoll-0.22.0.pkg"
  name "Idavoll"
  desc "Workspace installer for the 21Stark fleet, with its CLI"
  homepage "https://github.com/21StarkCom/homebrew-tap"

  depends_on arch: :arm64        # the app and the CLI are arm64 Mach-Os
  depends_on macos: :ventura     # the app's LSMinimumSystemVersion is 13.0

  pkg "idavoll-#{version}.pkg"

  # The package id the .pkg installs under (`pkgutil --pkg-info com.21stark.idavoll`): its
  # receipt lists /Applications/Idavoll.app and /usr/local/bin/idavoll.
  uninstall quit:    "com.21stark.idavoll.app",
            pkgutil: "com.21stark.idavoll"

  # `brew uninstall --zap` only. A packaged Idavoll.app registers itself as a login item with
  # `SMAppService.mainApp` on its first start, which outlives the bundle, so the zap deletes that
  # login item by its display name through System Events (macOS asks for the terminal's
  # Automation access). Electron names the userData folder after package.json's `name`.
  zap login_item: "Idavoll",
      trash:      [
        "~/Library/Application Support/idavoll-app",
        "~/Library/Preferences/com.21stark.idavoll.app.plist",
      ]
end
