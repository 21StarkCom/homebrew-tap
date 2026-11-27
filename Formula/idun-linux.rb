# frozen_string_literal: true

# Linux x86_64 build of the idun personal-ops maintenance CLI, for the devbox. Its own
# formula because a url cannot sit in an on_linux block (hermod ADR 0013);
# Formula/idun.rb is the macOS build. idun's release-darwin.sh cross-compiles it
# (idun docs/specs/vm-app.md, "The Linux release").
class IdunLinux < Formula
  desc "Personal-ops maintenance CLI, Linux x86_64 build"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/idun
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/idun-linux-v0.181.1/idun_v0.181.1_linux_x64.zip"
  version "0.181.1"
  sha256 "8b9562a4c7c468971fe1627ee6b5f493dec42dab3a700155aa409be87fc14df4"

  depends_on arch: :x86_64 # bun build --compile --target=bun-linux-x64
  depends_on :linux

  def install
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
