# frozen_string_literal: true

# Linux x86_64 build of ghx, the GitHub-work CLI from the github-extended repo, for the devbox.
# Its own formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/ghx.rb is the macOS build. github-extended's scripts/release-darwin.sh
# cross-compiles it beside the macOS one. ghx was njord up to 0.32.1: it keeps a `njord` link.
class GhxLinux < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/github-extended
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/ghx-linux-v0.33.0/ghx_0.33.0_linux_x64.zip"
  version "0.33.0"
  sha256 "a4c280962a6493528a6f29c1dd5250650bc0b8dbdfce3c7eb07b0d29f763574a"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "ghx"
    bin.install_symlink "ghx" => "njord"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
    assert_match version.to_s, shell_output("#{bin}/njord --version")
  end
end
