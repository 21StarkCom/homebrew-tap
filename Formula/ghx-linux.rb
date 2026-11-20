# frozen_string_literal: true

# Linux x86_64 build of ghx, the GitHub-work CLI from the github-extended repo, for the devbox.
# Its own formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/ghx.rb is the macOS build. github-extended's scripts/release-darwin.sh
# cross-compiles it beside the macOS one. ghx was njord up to 0.32.1: it keeps a `njord` link.
class GhxLinux < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/github-extended"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/github-extended/releases/assets/772396385",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.33.0"
  sha256 "a4c280962a6493528a6f29c1dd5250650bc0b8dbdfce3c7eb07b0d29f763574a"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "ghx"
    bin.install_symlink "ghx" => "njord"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
    assert_match version.to_s, shell_output("#{bin}/njord --version")
  end
end
