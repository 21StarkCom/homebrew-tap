# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of ghx, the GitHub-work CLI from the github-extended
# repo. ghx was njord, an app of the idun repo, up to 0.32.1: this formula keeps a `njord` link to it.
class Ghx < Formula
  desc "GitHub work CLI: pull requests, CI, Actions runs, cleanup and fleet repos"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/github-extended
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/ghx-v0.33.0/ghx_0.33.0_darwin_arm64.zip"
  version "0.33.0"
  sha256 "a59b1ae6c0ce5f2c0a2de91f8f7ebafadc52a28f8040d5fdc44705dba267428a"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "ghx"
    bin.install_symlink "ghx" => "njord"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ghx --version")
    assert_match version.to_s, shell_output("#{bin}/njord --version")
  end
end
