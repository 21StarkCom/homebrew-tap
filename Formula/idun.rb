require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class IdunPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private idun tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Ad-hoc-signed macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops maintenance CLI: GitHub identity swap, seat rotation, cleanup, housekeeping"
  homepage "https://github.com/21StarkCom/idun"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/idun/releases/assets/544543898",
      using: IdunPrivateReleaseStrategy
  version "0.16.0"
  sha256 "6248fdc7b2c7d6b13a9c9dacafd422816835c4c768fbf5a02d7817c9a13ab3d6"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
