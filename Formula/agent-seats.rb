# frozen_string_literal: true

# Developer-ID-signed (not notarized) macOS build of agent-seats (bun build --compile):
# several Claude Code and Codex logins on one Mac, the daemon that rotates them, and
# the seat-login CLI. The Developer ID keeps Keychain grants across upgrades.
class AgentSeats < Formula
  desc "Claude Code and Codex logins on one Mac: rotation, live usage, one daemon"
  homepage "https://github.com/21StarkCom/agent-seats"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/agent-seats/releases/assets/691596406",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.25.1"
  sha256 "9589a7dffabc548ddc67bfd461b6817f5ac0ab508358c9ea08d872c9d71f7b95"
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
    bin.install "agent-seats", "seat-login"
  end

  def caveats
    <<~EOS
      To run the daemon at login, register it once:
        agent-seats daemon install
      After an upgrade, restart the daemon so it runs the new binary:
        agent-seats daemon restart
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/agent-seats --version").strip
    assert_match "seat-login", shell_output("#{bin}/seat-login --help")
  end
end
