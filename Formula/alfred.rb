# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of alfred: the manual-ticket CLI
# (alfred) plus its always-on local daemon (alfredd). After install, run
# `alfredd install` to load the LaunchAgent — its plist pins the stable Homebrew
# opt path, so `brew upgrade alfred` never orphans the daemon.
class Alfred < Formula
  desc "Manual-ticket CLI + always-on local daemon for the 21Stark work fleet"
  homepage "https://github.com/21StarkCom/alfred"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/alfred/releases/assets/601587821",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.37.0"
  sha256 "362de9f77fd38ac689f13c3695e54f7df10ede2988ea064764225e669f223be9"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "alfred", "alfredd"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/alfred version")
  end
end
