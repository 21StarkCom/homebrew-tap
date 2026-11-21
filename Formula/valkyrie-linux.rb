# frozen_string_literal: true

# Linux x86_64 build of valkyrie, the agent-launcher CLI from the idun repo, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/valkyrie.rb is the macOS build. idun's release-darwin.sh cross-compiles it
# (idun docs/specs/vm-app.md, "The Linux release").
class ValkyrieLinux < Formula
  desc "Agent launchers for Claude Code and Codex, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/valkyrie-linux-v0.20.0/valkyrie_0.20.0_linux_x64.zip"
  version "0.20.0"
  sha256 "da73a403c3845a1bbef5f1bb9f6b6f2066ec6259fd8f580899b68f7dbe165b7b"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "valkyrie"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/valkyrie --version")
  end
end
