# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of ghx, the GitHub-work CLI from the github-extended
# repo. ghx was njord, an app of the idun repo, up to 0.32.1: this formula keeps a `njord` link to it.
class Ghx < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, cleanup and fleet repos"
  homepage "https://github.com/21StarkCom/github-extended"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/github-extended/releases/assets/772396388",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.33.0"
  sha256 "a59b1ae6c0ce5f2c0a2de91f8f7ebafadc52a28f8040d5fdc44705dba267428a"
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
    bin.install "ghx"
    bin.install_symlink "ghx" => "njord"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
    assert_match version.to_s, shell_output("#{bin}/njord --version")
  end
end
