# frozen_string_literal: true

# Linux x86_64 build of utgard, the remote-VM CLI from 21StarkCom/utgard, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/utgard.rb is the macOS build. utgard's release-darwin.sh cross-compiles it
# (utgard docs/specs/vm-app.md, "The Linux release").
class UtgardLinux < Formula
  desc "Remote VMs: the devbox and the winbox, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/utgard
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/utgard-linux-v0.18.5/utgard_0.18.5_linux_x64.zip"
  version "0.18.5"
  sha256 "8e7ed560935c18f455a44585937854efbc4f8aa002e1b86028bb56c47937d01e"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "utgard"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/utgard --version")
  end
end
