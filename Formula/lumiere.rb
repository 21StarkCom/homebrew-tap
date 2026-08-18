require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Kept minimal — no Homebrew-internal
# GitHub API helpers, which change between versions.
class GitHubPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    raise CurlDownloadStrategyError, "HOMEBREW_GITHUB_API_TOKEN is required for the private lumiere tap." if token.to_s.empty?
    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Signed (Developer ID) + notarized macOS build of the 21Stark visual-media
# toolkit — 16 lumiere-* CLIs.
class Lumiere < Formula
  desc "Visual-media CLI toolkit: image gen/edit, SVG suite, video, brand icons (16 tools)"
  homepage "https://github.com/21StarkCom/lumiere"
  version "0.1.0"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/lumiere/releases/assets/519984540",
      using: GitHubPrivateReleaseStrategy
  sha256 "a757d7f5b6bb1e3c67cc0934c47876870f87a4866066c4dad5cb951849d2573a"
  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install Dir["lumiere-*"]
  end

  test do
    assert_match "0.1.0", shell_output("#{bin}/lumiere-svg -version")
  end
end
