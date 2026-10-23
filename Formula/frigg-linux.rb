# frozen_string_literal: true

# Linux x86_64 build of the frigg IT-ops tools, for the devbox. Its own formula
# because a url cannot sit in an on_linux block (hermod ADR 0013); Formula/frigg.rb
# is the macOS build. Static Go binaries, unsigned: Linux has no Gatekeeper. Built +
# published by frigg's GitHub Actions release workflow (STARK-11775).
class FriggLinux < Formula
  desc "Google Workspace IT-ops toolkit for Linux: frigg CLI, frigg-* and gws-* tools"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten when frigg's
  # release calls the bumper with --asset-suffix linux_amd64.zip (the README's caller
  # table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/668331641",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.59.0"
  sha256 "4ebb0a0c1ed81339f16a0b33dba150031d6960f7064d59fbecb27cc49852f376"
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
