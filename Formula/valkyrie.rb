# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of valkyrie, the agent-launcher CLI from the idun repo.
class Valkyrie < Formula
  desc "Agent launchers: Claude Code and Codex sessions in tabs and worktrees"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/valkyrie-v0.18.0/valkyrie_0.18.0_darwin_arm64.zip"
  version "0.18.0"
  sha256 "250bd4075cb49faa2521b1a9ce47a7bff66886f392448f6afdc342c65c3415de"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "valkyrie"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/valkyrie --version")
  end
end
