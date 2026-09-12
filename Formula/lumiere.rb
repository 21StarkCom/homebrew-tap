require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern. Kept minimal — no
# Homebrew-internal GitHub API helpers, which change between versions.
class LumierePrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private lumiere tap."
    end

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
  desc "Visual-media CLI toolkit: image gen/edit, SVG, video, brand icons (16 tools)"
  homepage "https://github.com/21StarkCom/lumiere"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/lumiere/releases/assets/559164749",
      using: LumierePrivateReleaseStrategy
  version "0.3.0"
  sha256 "530b43c1331a4ee4e9de38958130952e3cc18dff8ab37674af88e7a85848bd1c"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install Dir["lumiere-*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lumiere-svg -version")
  end
end
