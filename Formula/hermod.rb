# frozen_string_literal: true

# Ad-hoc-signed macOS build of the hermod control-API CLI (renamed from
# cmux-client, STARK-1758).
class Hermod < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/hermod"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/hermod/releases/assets/585306714",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.22.0"
  sha256 "55c1a0ddf08f51a43a621af83bf7fe291c2e58fb7e2f8fa7529ad56e2abf800a"
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
