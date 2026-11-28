# frozen_string_literal: true

# Linux x86_64 build of muxctl, the control-API CLI of the mux-control repo, for the devbox's
# tmux (mux-control ADR 0012). Its own formula because a url cannot sit in an on_linux block
# (mux-control ADR 0013); Formula/muxctl.rb is the macOS build. This formula was named
# hermod-linux up to 0.52.0 (STARK-19541): it keeps a `hermod` link to muxctl.
class MuxctlLinux < Formula
  desc "TypeScript CLI + engine for the cmux control API, on Linux through tmux"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/mux-control
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/muxctl-linux-v0.55.0/muxctl_v0.55.0_linux_x64.zip"
  version "0.55.0"
  sha256 "e066caf962aebdd94cc41f357ae58dc5aa62fe82fc66cdf54c29aeae8c4ea62c"

  # muxctl finds a repo's checkout with `urd repos get`; urd-linux installs that `urd`.
  depends_on "21starkcom/tap/urd-linux"
  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "muxctl"
    bin.install_symlink "muxctl" => "hermod"
  end

  test do
    assert_equal "muxctl v#{version}", shell_output("#{bin}/muxctl version").strip
    assert_equal "muxctl v#{version}", shell_output("#{bin}/hermod version").strip
  end
end
