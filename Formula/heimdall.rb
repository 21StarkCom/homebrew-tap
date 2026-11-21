# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of heimdall: the native-APNs
# push-relay CLI. `heimdall send` fires a Mac banner AND pushes to your iPhone /
# iPad via your own APNs. Config (backend URL + send-secret) reads from the login
# Keychain (service "heimdall"), or HEIMDALL_URL / HEIMDALL_SEND_SECRET.
class Heimdall < Formula
  desc "Native-APNs push relay CLI: Mac banner + iPhone/iPad push via your own APNs"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/heimdall
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/heimdall-v0.2.0/heimdall_v0.2.0_darwin_arm64.zip"
  version "0.2.0"
  sha256 "4fb804895127094077dccfb61b199b3c5cd815dd213824e601878698e258086e"

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "heimdall"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/heimdall version")
  end
end
