# frozen_string_literal: true

# Linux x86_64 build of box, the CLI of the remote boxes from 21StarkCom/remote-boxes, for the
# devbox. Its own formula because a url cannot sit in an on_linux block (mux-control ADR 0013);
# Formula/box.rb is the macOS build. box's release-darwin.sh cross-compiles it
# (remote-boxes docs/specs/vm-app.md, "The Linux release"). This formula was named utgard-linux
# up to 0.18.5 (STARK-20349): it keeps a `utgard` link to box.
class BoxLinux < Formula
  desc "Remote boxes: the devbox and the winbox VMs, and the Macs, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/remote-boxes
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/box-linux-v0.19.0/box_0.19.0_linux_x64.zip"
  version "0.19.0"
  sha256 "39ca728d20af26591b1b05f094b9bcca32808b71077317fdc72967f38cee2288"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "box"
    bin.install_symlink "box" => "utgard"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/box --version").strip
    assert_equal version.to_s, shell_output("#{bin}/utgard --version").strip
  end
end
