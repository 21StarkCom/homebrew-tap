# frozen_string_literal: true

# Ad-hoc-signed macOS build of the hermod control-API CLI (renamed from
# cmux-client, STARK-1758).
class Hermod < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/hermod"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/hermod/releases/assets/603758813",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.29.1"
  sha256 "1465d2bde1108267ff84bc48edd5d63ad6b9b8a5554300cb6f01b670a899c373"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe # compiled with the release Mac's Homebrew bun, built for macOS 26.0; bare symbol == ">="

  def install
    bin.install "hermod"
  end

  test do
    assert_equal "hermod v#{version}", shell_output("#{bin}/hermod version").strip
  end
end
