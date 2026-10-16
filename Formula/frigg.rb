# frozen_string_literal: true

# Ad-hoc-signed macOS build of the frigg 21Stark IT-ops tools for Google Workspace and
# the vendor fleet. The binaries carry Go's linker ad-hoc signature, NOT
# Developer-ID/notarized — a formula's files install without the quarantine xattr, so
# Gatekeeper is not in the path. Built + published by frigg's GitHub Actions release
# workflow (STARK-2219).
class Frigg < Formula
  desc "Google Workspace IT-ops toolkit: frigg CLI, frigg-cockpit TUI, and gws-* CLIs"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten when frigg's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/646847620",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.53.0"
  sha256 "94b5891a9dadff588d5468975d3b663f5f7e7c92c2052d4a4e3c31be316c06db"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "frigg", "frigg-cockpit", "gws-align-managers", "gws-build-all-group"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/frigg --version")
    assert_match version.to_s, shell_output("#{bin}/frigg-cockpit --version")
    assert_match version.to_s, shell_output("#{bin}/gws-align-managers --version")
    assert_match version.to_s, shell_output("#{bin}/gws-build-all-group --version")
  end
end
