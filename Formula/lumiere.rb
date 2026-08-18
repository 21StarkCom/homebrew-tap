require "download_strategy"

# Signed (Developer ID) + notarized macOS build of the 21Stark visual-media
# toolkit — 16 lumiere-* CLIs. Private release asset, so it downloads through the
# GitHub API with your HOMEBREW_GITHUB_API_TOKEN.
class Lumiere < Formula
  desc "Visual-media CLI toolkit: image gen/edit, SVG suite, video, brand icons (16 tools)"
  homepage "https://github.com/21StarkCom/lumiere"
  version "0.1.0"
  url "https://github.com/21StarkCom/lumiere/releases/download/v0.1.0/lumiere_v0.1.0_darwin_arm64.zip",
      using: GitHubPrivateRepositoryReleaseDownloadStrategy
  sha256 "a757d7f5b6bb1e3c67cc0934c47876870f87a4866066c4dad5cb951849d2573a"
  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install Dir["lumiere-*"]
  end

  test do
    assert_match "0.1.0", shell_output("#{bin}/lumiere-svg -version")
  end
end
