# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of utgard, the remote-VM CLI, from 21StarkCom/utgard.
class Utgard < Formula
  desc "Remote VMs: the devbox and the winbox, run from the Mac"
  homepage "https://github.com/21StarkCom/utgard"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/utgard/releases/assets/772669013",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.18.0"
  sha256 "a3cfeca24132ec4d0aef00b5bb2c49f6eaf4008bf8f7a5bb2724bc0fb90a3059"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "utgard"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/utgard --version")
  end
end
