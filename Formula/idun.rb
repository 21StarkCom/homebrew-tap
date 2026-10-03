# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops CLI for GitHub identities, seat rotation, and housekeeping"
  homepage "https://github.com/21StarkCom/idun"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/idun/releases/assets/608648551",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.115.0"
  sha256 "fb07d87070f5711ffcb5fb3c46eac05cc7facafc56506e11a53b5233952c0b57"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
