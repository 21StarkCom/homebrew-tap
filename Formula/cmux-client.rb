require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class CmuxClientPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private cmux-client tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Ad-hoc-signed macOS build of the cmux-client control-API CLI.
class CmuxClient < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/cmux-client"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/cmux-client/releases/assets/531069090",
      using: CmuxClientPrivateReleaseStrategy
  version "0.3.0"
  sha256 "d69f54914bd25c36059220a281a157b6b5308bc05a64ae7cbfa4d52cc92e76df"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "cmux-client"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cmux-client version")
  end
end
