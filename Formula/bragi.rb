# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of bragi, the fleet's streaming-voice
# toolkit: the `bragi` CLI and `bragi-audio`, the Swift helper that owns the
# microphone and the speaker. bragi starts the helper from beside its own resolved
# path, so the two are installed side by side.
class Bragi < Formula
  desc "Streaming speech-to-text and text-to-speech for agents"
  homepage "https://github.com/21StarkCom/bragi"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/bragi/releases/assets/682372712",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.3.0"
  sha256 "017008de0c69fe67d62292deadfd4e1d7463eda4d4e0f46f762034c75ac563d1"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
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
