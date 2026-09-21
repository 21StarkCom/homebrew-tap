# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the 21Stark visual-media
# toolkit — the lumiere-* CLIs, plus the `lumiere` dispatcher that fronts them
# in the releases that ship one.
class Lumiere < Formula
  desc "Visual-media CLI toolkit: image gen/edit, SVG, video, brand icons"
  homepage "https://github.com/21StarkCom/lumiere"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/lumiere/releases/assets/552933023",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.2.1"
  sha256 "0bb732c60cbdea0d7beeccd86303460d52bda82ede85a43d3027fd2d8e7e0bd3"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    # The dispatcher ships as plain `lumiere`, which "lumiere-*" does not match.
    bin.install Dir["lumiere", "lumiere-*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lumiere-svg -version")
  end
end
