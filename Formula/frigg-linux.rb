# frozen_string_literal: true

# Linux x86_64 build of the frigg IT-ops tools, for the devbox. Its own formula
# because a url cannot sit in an on_linux block (hermod ADR 0013); Formula/frigg.rb
# is the macOS build. Static Go binaries, unsigned: Linux has no Gatekeeper. Built +
# published by frigg's GitHub Actions release workflow (STARK-11775).
class FriggLinux < Formula
  desc "Google Workspace IT-ops toolkit for Linux: frigg, frigg-*, frg-*, gws-* tools"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten when frigg's
  # release calls the bumper with --asset-suffix linux_amd64.zip (the README's caller
  # table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/699495971",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.70.1"
  sha256 "5b22257864078e9d0945ebb785d00f661751536c04a468f6ea2f683a5e328b54"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :x86_64 # frigg's release builds linux/amd64
  depends_on :linux

  def install
    # Globbed so the install tracks the tool set: frigg-cockpit, the vendor binaries and
    # their links (frigg-<command> up to v0.63.0; frg-<vendor> and frg-<command> from
    # v0.64.0, STARK-13456), and the gws-* tools; the zip's README.md matches no pattern.
    # The literal "frigg" fails the install on a zip without the main CLI, which no glob
    # matches.
    bin.install "frigg", *Dir["frigg-*", "frg-*", "gws-*"]
  end

  test do
    # Every frigg binary prints the release version on --version.
    bin.children.each { |tool| assert_match version.to_s, shell_output("#{tool} --version") }
  end
end
