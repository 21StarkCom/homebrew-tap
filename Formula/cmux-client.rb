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
  url "https://api.github.com/repos/21StarkCom/cmux-client/releases/assets/529519039",
      using: CmuxClientPrivateReleaseStrategy
  version "0.2.0"
  sha256 "94ba35b8db712b65022da29fcd39b97a30d61c43ce86ddbbbdcbfe66de83bca6"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "cmux-client"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/cmux-client version")
  end
end
