# frozen_string_literal: true

require "download_strategy"

# Cask URL specs are serialized by brew info and installed metadata. Keep the
# credential in the downloader only; inherit all native preflight/cache/resume.
class IdavollPrivateReleaseStrategy < CurlDownloadStrategy
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
# Homebrew reads Casks/**/*.rb; idavoll reads Casks/*.rb only. The GetEvinced mirror does
# not copy this cask: scripts/mirror.sh lists it in EXCLUDED, since the app's JavaScript
# is readable.
cask "idavoll" do
  # version / asset id / sha256 are release-specific and rewritten when idavoll's release
  # calls the bumper (the README's caller table) — do not hand-edit them.
  version "0.14.0"
  sha256 "019c5a9d1e7aa038be5effc278f6a9b661d751bb3e3e38f10ed89da147bcab1d"

  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # The download keeps the asset's own name (idavoll-<version>.pkg), which `pkg` names.
  url "https://api.github.com/repos/21StarkCom/idavoll/releases/assets/692383762",
      using: IdavollPrivateReleaseStrategy
  name "Idavoll"
  desc "Workspace installer for the 21Stark fleet, with its CLI"
  homepage "https://github.com/21StarkCom/idavoll"

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
