# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of utgard, the remote-VM CLI, from 21StarkCom/utgard.
class Utgard < Formula
  desc "Remote VMs: the devbox and the winbox, run from the Mac"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/utgard
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/utgard-v0.18.5/utgard_0.18.5_darwin_arm64.zip"
  version "0.18.5"
  sha256 "4a0cb828f39544b287c10aca782902a73a06c2b8f10931521a8d6d6da587a998"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "utgard"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/utgard --version")
  end
end
