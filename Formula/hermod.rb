require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class HermodPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private hermod tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Ad-hoc-signed macOS build of the hermod control-API CLI (renamed from
# cmux-client, STARK-1758).
class Hermod < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/hermod"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/hermod/releases/assets/548588185",
      using: HermodPrivateReleaseStrategy
  version "0.14.0"
  sha256 "ed97079d498210c39c34e1e0cef660c5b0e40ea6862cdb09c0e3ff6958875d1d"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "hermod"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/hermod version")
  end
end
