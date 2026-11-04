# frozen_string_literal: true

# Linux x86_64 build of urd, the local identity and infra cache, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013); Formula/urd.rb
# is the macOS build. A static Go binary, unsigned: Linux has no Gatekeeper. Built +
# published by urd's GitHub Actions release workflow (STARK-14363).
class UrdLinux < Formula
  desc "Local identity and infra cache for Linux: one SQLite file, synced from vendors"
  homepage "https://github.com/21StarkCom/urd"
  # version / asset id / sha256 are release-specific and rewritten when urd's
  # release calls the bumper with --asset-suffix linux_amd64.zip (the README's caller
  # table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/urd/releases/assets/709625696",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.13.0"
  sha256 "c4e53c6791feb4a9f80fa3424c1be8b1e291c3a1ebafb0c8ef35d9f5e9c3cb5a"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :x86_64 # urd's release builds linux/amd64
  depends_on :linux

  def install
    # The zip holds urd and a README.md; only the binary is installed.
    bin.install "urd"
  end

  test do
    # `urd version` prints "urd v<version>", its commit and its build date.
    assert_match "urd v#{version}", shell_output("#{bin}/urd version")
  end
end
