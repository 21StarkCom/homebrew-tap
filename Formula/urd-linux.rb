# frozen_string_literal: true

# Linux x86_64 build of urd, the local identity and infra cache, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013); Formula/urd.rb
# is the macOS build. A static Go binary, unsigned: Linux has no Gatekeeper. Built +
# published by urd's GitHub Actions release workflow (STARK-14363).
class UrdLinux < Formula
  desc "Local identity and infra cache for Linux: one SQLite file, synced from vendors"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # version / url / sha256 are rewritten when urd's release calls the bumper with
  # --asset-suffix linux_amd64.zip (the README's caller table) — do not hand-edit them.
  # Source release repo: 21StarkCom/urd
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/urd-linux-v0.15.1/urd_v0.15.1_linux_amd64.zip"
  version "0.15.1"
  sha256 "4d3c9e362f4be95e44aa4cceee1ed57cfa38224c2b6f28deb49109fbed445fd7"

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
