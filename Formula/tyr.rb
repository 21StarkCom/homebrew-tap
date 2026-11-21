# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the tyr vendor-integration CLI,
# frozen at its last CLI release: tyr is now a library-only Go module (frigg drives it).
class Tyr < Formula
  desc "Vendor-integration CLI: gh, Workspace, Atlassian, Slack, ClickUp, GCP and more"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/tyr
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/tyr-v0.109.0/tyr_v0.109.0_darwin_arm64.zip"
  version "0.109.0"
  sha256 "a8982839520c23c9ff563c45b535465cffe52763048fa803acc24b6d8cb81926"

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "tyr"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tyr version")
  end
end
