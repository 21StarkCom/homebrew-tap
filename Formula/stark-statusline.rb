# frozen_string_literal: true

# Ad-hoc-signed macOS build of stark-statusline, the Claude Code statusline:
# `stark-statusline render` draws it, and the bare command opens its layout
# editor. Cross-compiled darwin/arm64 (Go linker ad-hoc signature, NOT
# Developer-ID/notarized: a formula's files install without the quarantine
# xattr, so Gatekeeper is not in the path). Built + published by idavoll's
# statusline-release workflow (STARK-10552).
class StarkStatusline < Formula
  desc "Claude Code statusline: compiled renderer and terminal layout editor"
  homepage "https://github.com/21StarkCom/idavoll"
  # version / asset id / sha256 are release-specific and rewritten when idavoll's
  # statusline release calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  token = GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/idavoll/releases/assets/609417903",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.2"
  sha256 "80e1f009e2ff3393ab65d9083a149ccacf6f03ab2f28bff80db634c0d50b2e5f"
  # Homebrew's sandboxed workers reload this file where gh cannot read its config. They never
  # download (the brew process fetched first), so only that process must find a token.
  if token.empty? && %w[build.rb test.rb postinstall.rb].exclude?(File.basename($PROGRAM_NAME))
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login`, or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

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
