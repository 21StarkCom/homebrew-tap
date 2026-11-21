# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of valkyrie, the agent-launcher CLI from the idun repo.
class Valkyrie < Formula
  desc "Agent launchers: Claude Code and Codex sessions in tabs and worktrees"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/valkyrie-v0.20.0/valkyrie_0.20.0_darwin_arm64.zip"
  version "0.20.0"
  sha256 "4690fa77b13e63b0de12c891aeeea9102b40e95ccffa3f16203e67a4f2b456ef"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "valkyrie"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/valkyrie --version")
  end
end
