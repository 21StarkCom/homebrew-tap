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
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/idavoll/releases/assets/609267169",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.0"
  sha256 "62df2fccf883ff65e615b26ebdec877c5bef27cc5e44fdaef10e7715eac0d2b7"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "stark-statusline"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/stark-statusline --version")
  end
end
