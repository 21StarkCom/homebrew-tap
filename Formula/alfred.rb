# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of alfred: the manual-ticket CLI
# (alfred) plus its always-on local daemon (alfredd). After install, run
# `alfredd install` to load the LaunchAgent — its plist pins the stable Homebrew
# opt path, so `brew upgrade alfred` never orphans the daemon.
class Alfred < Formula
  desc "Manual-ticket CLI + always-on local daemon for the 21Stark work fleet"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/odin
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/alfred-v0.90.0/alfred_v0.90.0_darwin_arm64.zip"
  version "0.90.0"
  sha256 "ff8a7173e45da366e5513092f25de1bbec473a3e3046c4175263dc9a4daa911c"

  # alfred reads people, identity and org data through `urd`. Tap-qualified: a bare name
  # resolves to homebrew/core first, and is ambiguous when another tap ships a `urd`.
  depends_on "21starkcom/tap/urd"
  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "alfred", "alfredd"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/alfred version")
  end
end
