# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops CLI for GitHub identities, seat rotation, and housekeeping"
  homepage "https://github.com/21StarkCom/idun"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  token = GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/idun/releases/assets/608740537",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.116.0"
  sha256 "61d7e5217d5029c15aeafa927f45d142f6b9841d41d7b503fcca676feabe0384"
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
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
