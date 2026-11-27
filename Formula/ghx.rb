# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of ghx, the GitHub-work CLI from the github-extended repo.
class Ghx < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, cleanup and fleet repos"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/github-extended
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/ghx-v0.39.1/ghx_0.39.1_darwin_arm64.zip"
  version "0.39.1"
  sha256 "cc8352f4d57962547fa6c7bb31dd50cba108f80ed2a5ff0d9adc89fa80e9bd1c"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "ghx"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
  end
end
