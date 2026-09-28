# frozen_string_literal: true

# Ad-hoc-signed macOS build of the frigg 21Stark IT-ops CLIs for Google Workspace
# (manager-edge alignment + the all@ group-of-groups). Like idun, the binaries are
# ad-hoc-signed (Go's linker), NOT Developer-ID/notarized — Homebrew strips the
# quarantine xattr on install, so Gatekeeper is not in the path. Built + published
# by frigg's GitHub Actions release workflow (STARK-2219).
class Frigg < Formula
  desc "Google Workspace IT-ops toolkit: frigg CLI, frigg-cockpit TUI, and gws-* CLIs"
  homepage "https://github.com/21StarkCom/frigg"
  # version / asset id / sha256 are release-specific and rewritten when frigg's
  # release calls the bumper (the README's caller table) — do not hand-edit them.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/frigg/releases/assets/595141483",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.36.0"
  sha256 "625a1cdc117b24b364a0519c6da11cae070574a75cfe883053d90cf9b615303b"
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
