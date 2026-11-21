# frozen_string_literal: true

# Ad-hoc-signed macOS build of stark-statusline, the Claude Code statusline:
# `stark-statusline render` draws it, and the bare command opens its layout
# editor. A CGO-free darwin/arm64 build (Go linker ad-hoc signature, NOT
# Developer-ID/notarized: a formula's files install without the quarantine
# xattr, so Gatekeeper is not in the path). Built + published on the operator's
# Mac by idavoll's statusline/release.sh (STARK-10552).
class StarkStatusline < Formula
  desc "Claude Code statusline: compiled renderer and terminal layout editor"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idavoll
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/stark-statusline-v0.7.0/stark-statusline_0.7.0_darwin_arm64.zip"
  version "0.7.0"
  sha256 "101ea208c592d7b06188e7d34271d0bd90b7a489a398e2dae9d8658b822dcd4d"

  depends_on arch: :arm64
  depends_on macos: :ventura # Go's linker builds it for macOS 13.0; bare symbol == ">="

  def install
    bin.install "stark-statusline"
  end

  def caveats
    <<~EOS
      Run `stark-statusline install` to make it Claude Code's statusline: it points
      statusLine in ~/.claude/settings.json at `#{HOMEBREW_PREFIX}/bin/stark-statusline render`
      (the absolute path of the stark-statusline first on PATH), replacing any statusLine
      command already there. Run it again if an earlier install left the bare
      `stark-statusline render`, which Claude Code may run without Homebrew's bin on PATH.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/stark-statusline --version")
  end
end
