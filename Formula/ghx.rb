# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of ghx, the GitHub-work CLI from the github-extended repo.
class Ghx < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, cleanup and fleet repos"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/github-extended
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/ghx-v0.37.0/ghx_0.37.0_darwin_arm64.zip"
  version "0.37.0"
  sha256 "1e6b8eced3bfd027c009f5dce24eed1748fec4af55720d2ef31114a7c91a40f4"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "ghx"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
  end
end
