# frozen_string_literal: true

# Linux x86_64 build of sonar, the read-only CLI that resolves a vendor link to its content
# and probes a URL, for the devbox. Its own formula because a url cannot sit in an on_linux
# block (hermod ADR 0013); Formula/sonar.rb is the macOS build. A static Go binary,
# unsigned: Linux has no Gatekeeper. Built + published by sonar's GitHub Actions release
# workflow (STARK-18511).
class SonarLinux < Formula
  desc "Read-only CLI that resolves vendor links and probes URLs, for Linux"
  homepage "https://github.com/21StarkCom/sonar"
  # version / asset id / sha256 are release-specific and rewritten when sonar's
  # release calls the bumper with --asset-suffix linux_amd64.zip (the README's caller
  # table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/sonar/releases/assets/744377839",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.2.0"
  sha256 "d136fca6d61e0b8806467a3ceeddb1d2b7537b84bf8330e64b6d94d1f804e07e"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :x86_64 # sonar's release builds linux/amd64
  depends_on :linux

  def install
    # The zip holds only the sonar binary, at its root.
    bin.install "sonar"
  end

  test do
    # `sonar --version` prints the bare version, such as "0.1.0".
    assert_equal version.to_s, shell_output("#{bin}/sonar --version").strip
  end
end
