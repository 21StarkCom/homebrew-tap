# frozen_string_literal: true

# Ad-hoc-signed macOS build of urd, the 21Stark local identity and infra cache. The
# binary carries Go's linker ad-hoc signature, NOT Developer-ID/notarized — a formula's
# files install without the quarantine xattr, so Gatekeeper is not in the path. Built +
# published by urd's GitHub Actions release workflow (STARK-14363).
class Urd < Formula
  desc "Local identity and infra cache: one SQLite file, synced from vendors"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/urd
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/urd-v0.16.0/urd_v0.16.0_darwin_arm64.zip"
  version "0.16.0"
  sha256 "1405053732e23cc12550b2d7afbf8b784aa72059a502a82874fd1d057189713f"

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
