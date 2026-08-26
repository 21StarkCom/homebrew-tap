require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class TyrPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private tyr tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Signed (Developer ID) + notarized macOS build of the tyr vendor-integration CLI.
class Tyr < Formula
  desc "Vendor-integration CLI: gh, Workspace, Atlassian, Slack, ClickUp, GCP and more"
  homepage "https://github.com/21StarkCom/tyr"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/tyr/releases/assets/530550785",
      using: TyrPrivateReleaseStrategy
  version "0.107.0"
  sha256 "37c0e18f550a114080a54c9daddcea0d4da10c753e2998fcc8f755b43b464cc1"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "tyr"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tyr version")
  end
end
