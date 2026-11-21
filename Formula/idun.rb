# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops CLI for GitHub identities, seat rotation, and housekeeping"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/idun-v0.179.1/idun_v0.179.1_darwin_arm64.zip"
  version "0.179.1"
  sha256 "471c3d0f4c86387d2534f1f4783b2516cfd5316881ed63988309cf2da2b19e6a"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
