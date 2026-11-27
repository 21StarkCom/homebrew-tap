# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of box, the CLI of the remote boxes, from
# 21StarkCom/remote-boxes. This formula was named utgard up to 0.18.5 (STARK-20349): it keeps a
# `utgard` link to box.
class Box < Formula
  desc "Remote boxes: the devbox and the winbox VMs, and the Macs, run from the Mac"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/remote-boxes
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/box-v0.19.0/box_0.19.0_darwin_arm64.zip"
  version "0.19.0"
  sha256 "e4d23222edaba2ab0e01f3905689f9a9931be84cdda0419dc51f176cd90e15fe"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "box"
    bin.install_symlink "box" => "utgard"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/box --version").strip
    assert_equal version.to_s, shell_output("#{bin}/utgard --version").strip
  end
end
