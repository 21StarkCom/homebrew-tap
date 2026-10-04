# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the 21Stark visual-media
# toolkit — the lumiere-* CLIs, plus the `lumiere` dispatcher that fronts them.
class Lumiere < Formula
  desc "Visual-media CLI toolkit: image gen/edit, SVG, video, brand icons"
  homepage "https://github.com/21StarkCom/lumiere"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  token = GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/lumiere/releases/assets/592292376",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.4.2"
  sha256 "5db903a769d4d877a1295900bc06a734082df19c9a630a54dc7c4527924dfd30"
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
  depends_on macos: :tahoe # the four cgo (ONNX) tools are built for macOS 26.0; bare symbol == ">="

  def install
    # The dispatcher ships as plain `lumiere`, which "lumiere-*" does not match.
    bin.install Dir["lumiere", "lumiere-*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lumiere-svg -version")
    assert_match version.to_s, shell_output("#{bin}/lumiere --version")
    # The dispatcher execs `lumiere-<tool>` from beside itself in the keg.
    assert_match(/\Alumiere-svg v?#{Regexp.escape(version.to_s)}$/, shell_output("#{bin}/lumiere svg -version"))
    # One cgo (ONNX) tool, offline. Launching it fails if it was built for a newer macOS than
    # this one (v0.4.0 shipped minos 27.0, STARK-8882). Without the library-validation
    # entitlement it can't load the ONNX Runtime it downloads (v0.1.1-v0.4.1, STARK-9716).
    assert_match version.to_s, shell_output("#{bin}/lumiere-upscale -version")
    assert_match "com.apple.security.cs.disable-library-validation",
                 shell_output("codesign -d --entitlements - --xml #{bin}/lumiere-upscale 2>&1")
  end
end
