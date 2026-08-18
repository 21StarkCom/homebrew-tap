require "download_strategy"

# Downloads a private-repo GitHub Release asset via the API using
# HOMEBREW_GITHUB_API_TOKEN. Homebrew removed the built-in strategy, so it is
# defined inline here.
class GitHubPrivateReleaseStrategy < CurlDownloadStrategy
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    @token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    raise CurlDownloadStrategyError, "HOMEBREW_GITHUB_API_TOKEN is required for the private lumiere tap." if @token.to_s.empty?
    m = @url.match(%r{https://github.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(\S+)})
    raise CurlDownloadStrategyError, "Bad GitHub release URL." unless m
    _, @owner, @repo, @tag, @filename = *m
  end

  def _fetch(url:, resolved_url:, timeout:)
    release = GitHub.open_api("https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}")
    asset = release["assets"].find { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset #{@filename} not found on #{@tag}." unless asset
    curl "--location", "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{@token}",
         "--output", temporary_path.to_s,
         "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset["id"]}",
         timeout: timeout
  end
end

# Signed (Developer ID) + notarized macOS build of the 21Stark visual-media
# toolkit — 16 lumiere-* CLIs.
class Lumiere < Formula
  desc "Visual-media CLI toolkit: image gen/edit, SVG suite, video, brand icons (16 tools)"
  homepage "https://github.com/21StarkCom/lumiere"
  version "0.1.0"
  url "https://github.com/21StarkCom/lumiere/releases/download/v0.1.0/lumiere_v0.1.0_darwin_arm64.zip",
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
