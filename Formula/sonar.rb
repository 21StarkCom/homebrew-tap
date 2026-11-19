# frozen_string_literal: true

# Ad-hoc-signed macOS build of sonar, the read-only CLI that resolves a vendor link to its
# content and probes a URL. The binary carries Go's linker ad-hoc signature, NOT
# Developer-ID/notarized — a formula's files install without the quarantine xattr, so
# Gatekeeper is not in the path. Built + published by sonar's GitHub Actions release
# workflow (STARK-18511).
class Sonar < Formula
  desc "Read-only CLI that resolves vendor links and probes URLs"
  homepage "https://github.com/21StarkCom/sonar"
  # version / asset id / sha256 are release-specific and rewritten when sonar's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/sonar/releases/assets/768094877",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.15.2"
  sha256 "5fa6ee12a7458f4b2276a1aef55bbd1ba8d6f7251152eb0dd6490a8c9230f2c2"
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
    # The zip holds only the sonar binary, at its root.
    bin.install "sonar"
  end

  test do
    # `sonar --version` prints the bare version, such as "0.1.0".
    assert_equal version.to_s, shell_output("#{bin}/sonar --version").strip
  end
end
