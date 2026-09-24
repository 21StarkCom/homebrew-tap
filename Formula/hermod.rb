# frozen_string_literal: true

# Ad-hoc-signed macOS build of the hermod control-API CLI (renamed from
# cmux-client, STARK-1758).
class Hermod < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/hermod"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/hermod/releases/assets/586437393",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.24.0"
  sha256 "0cb24ceaac7d18a5594f7664ce8783415b5795113a6718785db36102fae3fb92"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "hermod"
  end

  test do
    assert_equal "hermod v#{version}", shell_output("#{bin}/hermod version").strip
  end
end
