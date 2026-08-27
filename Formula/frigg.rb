require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae/casks in this tap that ship the same pattern.
class FriggPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private frigg tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Ad-hoc-signed macOS build of the frigg 21Stark IT-ops CLIs for Google Workspace
# (manager-edge alignment + the all@ group-of-groups). Like idun, the binaries are
# ad-hoc-signed (Go's linker), NOT Developer-ID/notarized — Homebrew strips the
# quarantine xattr on install, so Gatekeeper is not in the path. Built + published
# by a GitLab CI/CD pipeline on gitlab.evinced.cloud (STARK-1193).
class Frigg < Formula
  desc "Google Workspace IT-ops toolkit: frigg TUI cockpit and gws-* CLIs"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten by the source
  # repo's bump tooling (frigg/scripts/bump-tap.sh) — do not hand-edit them. The
  # seed values below are placeholders until the first release's bump PR lands.
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/532035887",
      using: FriggPrivateReleaseStrategy
  version "0.5.2"
  sha256 "58cb7a04585f58df25e4a216d85e11131362e466bb710f4b774bebefe0cbd598"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "frigg", "gws-align-managers", "gws-build-all-group"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/frigg --version")
    assert_match version.to_s, shell_output("#{bin}/gws-align-managers --version")
    assert_match version.to_s, shell_output("#{bin}/gws-build-all-group --version")
  end
end
