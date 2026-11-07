# frozen_string_literal: true

# Ad-hoc-signed macOS build of stark-statusline, the Claude Code statusline:
# `stark-statusline render` draws it, and the bare command opens its layout
# editor. A CGO-free darwin/arm64 build (Go linker ad-hoc signature, NOT
# Developer-ID/notarized: a formula's files install without the quarantine
# xattr, so Gatekeeper is not in the path). Built + published on the operator's
# Mac by idavoll's statusline/release.sh (STARK-10552).
class StarkStatusline < Formula
  desc "Claude Code statusline: compiled renderer and terminal layout editor"
  homepage "https://github.com/21StarkCom/idavoll"
  # version / asset id / sha256 are release-specific and rewritten when idavoll's
  # statusline release calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/idavoll/releases/assets/720262753",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.5.0"
  sha256 "73cba46d2c2b69b3d0ff2da3a4494ab93833703df0ccf13cf5da03230bc72212"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
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
