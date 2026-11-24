# frozen_string_literal: true

# Linux x86_64 build of the frigg IT-ops tools, for the devbox. Its own formula
# because a url cannot sit in an on_linux block (hermod ADR 0013); Formula/frigg.rb
# is the macOS build. Static Go binaries, unsigned: Linux has no Gatekeeper. Built +
# published by frigg's GitHub Actions release workflow (STARK-11775).
class FriggLinux < Formula
  desc "Google Workspace IT-ops toolkit for Linux: frigg, frigg-*, frg-*, gws-* tools"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # version / url / sha256 are rewritten when frigg's release calls the bumper with
  # --asset-suffix linux_amd64.zip (the README's caller table) — do not hand-edit them.
  # Source release repo: 21StarkCom/frigg
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/frigg-linux-v0.93.0/frigg_v0.93.0_linux_amd64.zip"
  version "0.93.0"
  sha256 "e8ea7b562b36dd535bb8506e2010498c45e8f9426749bd3d309325cd139337eb"

  depends_on arch: :x86_64 # frigg's release builds linux/amd64
  depends_on :linux

  def install
    # Globbed so the install tracks the tool set: frigg-cockpit, the vendor binaries and
    # their links (frigg-<command> up to v0.63.0; frg-<vendor> and frg-<command> from
    # v0.64.0, STARK-13456), and the gws-* tools; the zip's README.md matches no pattern.
    # The literal "frigg" fails the install on a zip without the main CLI, which no glob
    # matches.
    bin.install "frigg", *Dir["frigg-*", "frg-*", "gws-*"]
  end

  test do
    # Every frigg binary prints the release version on --version.
    bin.children.each { |tool| assert_match version.to_s, shell_output("#{tool} --version") }
  end
end
