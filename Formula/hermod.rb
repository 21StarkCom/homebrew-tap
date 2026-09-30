# frozen_string_literal: true

# Ad-hoc-signed macOS build of the hermod control-API CLI (renamed from
# cmux-client, STARK-1758).
class Hermod < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/hermod"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/hermod/releases/assets/601212077",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.27.1"
  sha256 "7892738e1f376559351fb56e4056d2462b071e70a55a5609442b6984f26d8ba2"
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
