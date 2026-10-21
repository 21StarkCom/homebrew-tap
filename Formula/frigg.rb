# frozen_string_literal: true

# Ad-hoc-signed macOS build of the frigg 21Stark IT-ops tools for Google Workspace and
# the vendor fleet. The binaries carry Go's linker ad-hoc signature, NOT
# Developer-ID/notarized — a formula's files install without the quarantine xattr, so
# Gatekeeper is not in the path. Built + published by frigg's GitHub Actions release
# workflow (STARK-2219).
class Frigg < Formula
  desc "Google Workspace IT-ops toolkit: frigg CLI, frigg-* and gws-* tools"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten when frigg's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/659228189",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.56.3"
  sha256 "01101c3633011701ee6840e47fe623f87ff0322ccbfb12691c310032402d453a"
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
    # Globbed so the install tracks the tool set as frigg carves out new frigg-* binaries;
    # the zip's README.md matches no pattern. The literal "frigg" fails the install on a
    # zip without the main CLI, which "frigg-*" does not match.
    bin.install "frigg", *Dir["frigg-*", "gws-*"]
  end

  test do
    # Every frigg binary prints the release version on --version.
    bin.children.each { |tool| assert_match version.to_s, shell_output("#{tool} --version") }
  end
end
