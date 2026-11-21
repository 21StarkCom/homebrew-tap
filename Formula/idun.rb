# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops CLI for GitHub identities, seat rotation, and housekeeping"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/idun-v0.180.0/idun_v0.180.0_darwin_arm64.zip"
  version "0.180.0"
  sha256 "7d492fd1193f2be9bc363d2cc990c3c40441a626843ffcd1d7e214163c83eb35"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
