# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of bragi, the fleet's streaming-voice
# toolkit: the `bragi` CLI and `bragi-audio`, the Swift helper that owns the
# microphone and the speaker. bragi starts the helper from beside its own resolved
# path, so the two are installed side by side.
class Bragi < Formula
  desc "Streaming speech-to-text and text-to-speech for agents"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/bragi
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/bragi-v0.6.0/bragi_v0.6.0_darwin_arm64.zip"
  version "0.6.0"
  sha256 "ac947fe3ac7ebeea04e3fbca12c2d93780e3af4b72e87ab9d33504c141e75500"

  depends_on arch: :arm64
  depends_on macos: :sequoia # bragi-audio is built for macOS 15; bare symbol == ">="

  def install
    bin.install "bragi", "bragi-audio"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bragi --version")
    # Launching the helper fails if it was built for a newer macOS than this one, or its
    # signature is broken; `--version` exits before it touches any audio.
    assert_match "bragi-audio protocol", shell_output("#{bin}/bragi-audio --version")
    # The helper records under the hardened runtime, which wants the microphone entitlement.
    assert_match %r{<key>com\.apple\.security\.device\.audio-input</key>\s*<true/>},
                 shell_output("codesign -d --entitlements - --xml #{bin}/bragi-audio 2>&1")
    # Since 0.4.0 the helper is its own responsible process, so macOS asks for the
    # microphone with the usage string in its embedded Info.plist; without it, no prompt.
    assert_match "NSMicrophoneUsageDescription",
                 shell_output("launchctl plist __TEXT,__info_plist #{bin}/bragi-audio")
  end
end
