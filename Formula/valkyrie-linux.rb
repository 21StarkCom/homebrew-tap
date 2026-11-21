# frozen_string_literal: true

# Linux x86_64 build of valkyrie, the agent-launcher CLI from the idun repo, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/valkyrie.rb is the macOS build. idun's release-darwin.sh cross-compiles it
# (idun docs/specs/vm-app.md, "The Linux release").
class ValkyrieLinux < Formula
  desc "Agent launchers for Claude Code and Codex, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/valkyrie-linux-v0.19.0/valkyrie_0.19.0_linux_x64.zip"
  version "0.19.0"
  sha256 "6d2bdb5590fcedd0d7073587d457fac06e843ca840bf6dc1f72a351c02633bbc"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "valkyrie"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/valkyrie --version")
  end
end
