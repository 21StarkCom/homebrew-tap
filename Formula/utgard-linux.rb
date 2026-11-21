# frozen_string_literal: true

# Linux x86_64 build of utgard, the remote-VM CLI from 21StarkCom/utgard, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/utgard.rb is the macOS build. utgard's release-darwin.sh cross-compiles it
# (utgard docs/specs/vm-app.md, "The Linux release").
class UtgardLinux < Formula
  desc "Remote VMs: the devbox and the winbox, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/utgard
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/utgard-linux-v0.18.4/utgard_0.18.4_linux_x64.zip"
  version "0.18.4"
  sha256 "627f5e3b2e4c9d88b121cf8e698f0b20da28b4f07d909c03a51f5d90fc49f8e2"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "utgard"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/utgard --version")
  end
end
