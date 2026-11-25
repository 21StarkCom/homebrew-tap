# frozen_string_literal: true

# Ad-hoc-signed macOS build of the frigg 21Stark IT-ops tools for Google Workspace and
# the vendor fleet. The binaries carry Go's linker ad-hoc signature, NOT
# Developer-ID/notarized — a formula's files install without the quarantine xattr, so
# Gatekeeper is not in the path. Built + published by frigg's GitHub Actions release
# workflow (STARK-2219).
class Frigg < Formula
  desc "Google Workspace IT-ops toolkit: frigg CLI, frigg-*, frg-* and gws-* tools"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/frigg
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/frigg-v0.97.0/frigg_v0.97.0_darwin_arm64.zip"
  version "0.97.0"
  sha256 "d0baa4e5872b6943c854141921efcc7c64e0e8cb1243e4b9ae3b8a5f18587d37"

  depends_on arch: :arm64
  depends_on :macos

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
