# frozen_string_literal: true

# Ad-hoc-signed macOS build of urd, the 21Stark local identity and infra cache. The
# binary carries Go's linker ad-hoc signature, NOT Developer-ID/notarized — a formula's
# files install without the quarantine xattr, so Gatekeeper is not in the path. Built +
# published by urd's GitHub Actions release workflow (STARK-14363).
class Urd < Formula
  desc "Local identity and infra cache: one SQLite file, synced from vendors"
  homepage "https://github.com/21StarkCom/urd"
  # version / asset id / sha256 are release-specific and rewritten when urd's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/urd/releases/assets/699610596",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.12.0"
  sha256 "8942f377572cebf07606e37832839b20d85a88fb3e381220f13f9049a90c366f"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    # The zip holds urd and a README.md; only the binary is installed.
    bin.install "urd"
  end

  def caveats
    <<~EOS
      urd syncs every 6 hours only after you install its launchd agent:
        urd schedule install
      Homebrew does not remove that agent. Before `brew uninstall urd`, run:
        urd schedule uninstall
    EOS
  end

  test do
    # `urd version` prints "urd v<version>", its commit and its build date.
    assert_match "urd v#{version}", shell_output("#{bin}/urd version")
  end
end
