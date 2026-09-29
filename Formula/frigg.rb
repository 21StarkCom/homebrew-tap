# frozen_string_literal: true

# Ad-hoc-signed macOS build of the frigg 21Stark IT-ops tools for Google Workspace and
# the vendor fleet. The binaries carry Go's linker ad-hoc signature, NOT
# Developer-ID/notarized — a formula's files install without the quarantine xattr, so
# Gatekeeper is not in the path. Built + published by frigg's GitHub Actions release
# workflow (STARK-2219).
class Frigg < Formula
  desc "Google Workspace IT-ops toolkit: frigg CLI, frigg-cockpit TUI, and gws-* CLIs"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten when frigg's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/596079034",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.37.0"
  sha256 "ec594092ff0ddc23c6919ddcfa2270e7ff38f52684f83e58614c9dc6ea540093"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "frigg", "frigg-cockpit", "gws-align-managers", "gws-build-all-group"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/frigg --version")
    assert_match version.to_s, shell_output("#{bin}/frigg-cockpit --version")
    assert_match version.to_s, shell_output("#{bin}/gws-align-managers --version")
    assert_match version.to_s, shell_output("#{bin}/gws-build-all-group --version")
  end
end
