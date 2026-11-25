# frozen_string_literal: true

# Linux x86_64 build of sonar, the read-only CLI that resolves a vendor link to its content
# and probes a URL, for the devbox. Its own formula because a url cannot sit in an on_linux
# block (hermod ADR 0013); Formula/sonar.rb is the macOS build. A static Go binary,
# unsigned: Linux has no Gatekeeper. Built + published by sonar's GitHub Actions release
# workflow (STARK-18511).
class SonarLinux < Formula
  desc "Read-only CLI that resolves vendor links and probes URLs, for Linux"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # version / url / sha256 are rewritten when sonar's release calls the bumper with
  # --asset-suffix linux_amd64.zip (the README's caller table) — do not hand-edit them.
  # Source release repo: 21StarkCom/sonar
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/sonar-linux-v0.18.0/sonar_v0.18.0_linux_amd64.zip"
  version "0.18.0"
  sha256 "c9f54cf61bbc2472aa2bee77a7f0ec24f02b939b5f6294cb7add39d5ce862c19"

  depends_on arch: :x86_64 # sonar's release builds linux/amd64
  depends_on :linux

  def install
    # The zip holds only the sonar binary, at its root.
    bin.install "sonar"
  end

  test do
    # `sonar --version` prints the bare version, such as "0.1.0".
    assert_equal version.to_s, shell_output("#{bin}/sonar --version").strip
  end
end
