# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops CLI for GitHub identities, seat rotation, and housekeeping"
  homepage "https://github.com/21StarkCom/idun"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/idun/releases/assets/704430246",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.160.0"
  sha256 "26a3b9e4c80fd3621c83cb4176163bbb2065e6743d3cf4f7f683cedf279a07d1"
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
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
