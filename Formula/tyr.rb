# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the tyr vendor-integration CLI,
# frozen at its last CLI release: tyr is now a library-only Go module (frigg drives it).
class Tyr < Formula
  desc "Vendor-integration CLI: gh, Workspace, Atlassian, Slack, ClickUp, GCP and more"
  homepage "https://github.com/21StarkCom/tyr"
  # API asset URL (private repo). No release bumps this formula: tyr ships no binary now.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/tyr/releases/assets/532798162",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.109.0"
  sha256 "a8982839520c23c9ff563c45b535465cffe52763048fa803acc24b6d8cb81926"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "tyr"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tyr version")
  end
end
