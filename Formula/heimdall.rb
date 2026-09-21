# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of heimdall: the native-APNs
# push-relay CLI. `heimdall send` fires a Mac banner AND pushes to your iPhone /
# iPad via your own APNs. Config (backend URL + send-secret) reads from the login
# Keychain (service "heimdall"), or HEIMDALL_URL / HEIMDALL_SEND_SECRET.
class Heimdall < Formula
  desc "Native-APNs push relay CLI: Mac banner + iPhone/iPad push via your own APNs"
  homepage "https://github.com/21StarkCom/heimdall"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/heimdall/releases/assets/532655731",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.0"
  sha256 "8ffdbf5820d1671420ffbf616a8e0008c20031b1c247555b97b9653ade87d36f"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
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
