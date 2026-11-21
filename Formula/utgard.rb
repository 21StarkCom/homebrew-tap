# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of utgard, the remote-VM CLI, from 21StarkCom/utgard.
class Utgard < Formula
  desc "Remote VMs: the devbox and the winbox, run from the Mac"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/utgard
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/utgard-v0.18.4/utgard_0.18.4_darwin_arm64.zip"
  version "0.18.4"
  sha256 "b36667323f9f0e48656b85304c35880b2a8b8330993e4382e956ed8fd001a458"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "utgard"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/utgard --version")
  end
end
