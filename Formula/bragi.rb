# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of bragi, the fleet's streaming-voice
# toolkit: the `bragi` CLI and `bragi-audio`, the Swift helper that owns the
# microphone and the speaker. bragi starts the helper from beside its own resolved
# path, so the two are installed side by side.
class Bragi < Formula
  desc "Streaming speech-to-text and text-to-speech for agents"
  homepage "https://github.com/21StarkCom/bragi"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/bragi/releases/assets/605904447",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.0"
  sha256 "ec52675bf76c6e3464403bbf48aefefb0c7681ec747723b3fe4fa85d77cee836"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

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
  end
end
