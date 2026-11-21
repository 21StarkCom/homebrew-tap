# frozen_string_literal: true

# Linux x86_64 build of valkyrie, the agent-launcher CLI from the idun repo, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/valkyrie.rb is the macOS build. idun's release-darwin.sh cross-compiles it
# (idun docs/specs/vm-app.md, "The Linux release").
class ValkyrieLinux < Formula
  desc "Agent launchers for Claude Code and Codex, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/idun"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/idun/releases/assets/775506170",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.18.0"
  sha256 "1af8b22b5da5e3c50a1bd2e8864b7aabfbbccd9cd4c708265ea60cb87a4af0bd"
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
    bin.install "valkyrie"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/valkyrie --version")
  end
end
