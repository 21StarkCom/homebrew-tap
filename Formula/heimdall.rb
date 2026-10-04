# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of heimdall: the native-APNs
# push-relay CLI. `heimdall send` fires a Mac banner AND pushes to your iPhone /
# iPad via your own APNs. Config (backend URL + send-secret) reads from the login
# Keychain (service "heimdall"), or HEIMDALL_URL / HEIMDALL_SEND_SECRET.
class Heimdall < Formula
  desc "Native-APNs push relay CLI: Mac banner + iPhone/iPad push via your own APNs"
  homepage "https://github.com/21StarkCom/heimdall"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  token = GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/heimdall/releases/assets/598942000",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.2.0"
  sha256 "4fb804895127094077dccfb61b199b3c5cd815dd213824e601878698e258086e"
  # Homebrew's sandboxed workers reload this file where gh cannot read its config. They never
  # download (the brew process fetched first), so only that process must find a token.
  if token.empty? && %w[build.rb test.rb postinstall.rb].exclude?(File.basename($PROGRAM_NAME))
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login`, or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "heimdall"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/heimdall version")
  end
end
