# frozen_string_literal: true

# Linux x86_64 build of the hermod control-API CLI, for the devbox's tmux (hermod
# ADR 0012). Its own formula because a url cannot sit in an on_linux block
# (hermod ADR 0013); Formula/hermod.rb is the macOS build.
class HermodLinux < Formula
  desc "TypeScript CLI + engine for the cmux control API, on Linux through tmux"
  homepage "https://github.com/21StarkCom/hermod"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/hermod/releases/assets/754335942",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.51.0"
  sha256 "bde9b00cef5bdfad427ffd3e4aca249477c661e04537803284b84e902b5a7cfc"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  # hermod finds a repo's checkout with `urd repos get`; urd-linux installs that `urd`.
  depends_on "21starkcom/tap/urd-linux"
  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "hermod"
  end

  test do
    assert_equal "hermod v#{version}", shell_output("#{bin}/hermod version").strip
  end
end
