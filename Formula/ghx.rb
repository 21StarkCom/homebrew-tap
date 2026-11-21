# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of ghx, the GitHub-work CLI from the github-extended repo.
class Ghx < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, cleanup and fleet repos"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/github-extended
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/ghx-v0.34.0/ghx_0.34.0_darwin_arm64.zip"
  version "0.34.0"
  sha256 "aa10f3c03925b25905a8aa9d2c09ce36dd756fe9371a2a81494b3417a1a52217"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "ghx"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
  end
end
