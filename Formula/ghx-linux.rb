# frozen_string_literal: true

# Linux x86_64 build of ghx, the GitHub-work CLI from the github-extended repo, for the devbox.
# Its own formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/ghx.rb is the macOS build. github-extended's scripts/release-darwin.sh
# cross-compiles it beside the macOS one.
class GhxLinux < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/github-extended
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/ghx-linux-v0.39.1/ghx_0.39.1_linux_x64.zip"
  version "0.39.1"
  sha256 "f2969bfd2ea8564ac3d4874bfc1c004e978b329f989c93b3bbb5d03626b2ea41"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "ghx"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
  end
end
