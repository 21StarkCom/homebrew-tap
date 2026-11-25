# frozen_string_literal: true

# Ad-hoc-signed macOS build of sonar, the read-only CLI that resolves a vendor link to its
# content and probes a URL. The binary carries Go's linker ad-hoc signature, NOT
# Developer-ID/notarized — a formula's files install without the quarantine xattr, so
# Gatekeeper is not in the path. Built + published by sonar's GitHub Actions release
# workflow (STARK-18511).
class Sonar < Formula
  desc "Read-only CLI that resolves vendor links and probes URLs"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/sonar
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/sonar-v0.18.0/sonar_v0.18.0_darwin_arm64.zip"
  version "0.18.0"
  sha256 "b6fd951878091e4093dea5974b96aff904301c0199a558b4cf8273ebab8a02c8"

  depends_on arch: :arm64
  depends_on :macos

  def install
    # The zip holds only the sonar binary, at its root.
    bin.install "sonar"
  end

  test do
    # `sonar --version` prints the bare version, such as "0.1.0".
    assert_equal version.to_s, shell_output("#{bin}/sonar --version").strip
  end
end
