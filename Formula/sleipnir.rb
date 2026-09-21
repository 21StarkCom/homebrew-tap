# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of sleipnir — a CLI that drives
# dedicated, persistent Chrome profiles for ad-hoc agent tasks. Bun runs the
# TypeScript directly (no build step), so the zip ships the source tree + vendored
# prod node_modules; the one compiled artifact is the Swift mac-helper.
class Sleipnir < Formula
  desc "Drive dedicated, persistent Chrome profiles for ad-hoc agent tasks"
  homepage "https://github.com/21StarkCom/sleipnir"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/sleipnir/releases/assets/576465177",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.7.0"
  sha256 "50980cb2293705a1b6d431a31458786201b72b23fdde374334335a2a6fa4a4a8"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64 # the shipped mac-helper is a signed arm64 Mach-O
  depends_on "bun" # Bun runs the TypeScript directly; sleipnir has no build step
  depends_on :macos # drives system Chrome + a Swift AX/CGEvent helper

  def install
    # The zip is the runnable tree (app.ts, bin/, packages/, vendored node_modules,
    # and the signed helper at packages/mac-helper/.build/release/mac-helper). The
    # helper is resolved relative to packages/mac/src, so the layout must be kept
    # intact — install the whole tree into libexec and wrap the entry point.
    libexec.install Dir["*"]
    %w[sleipnir slp].each do |name|
      (bin/name).write <<~SH
        #!/bin/bash
        exec "#{formula_opt_bin("bun")}/bun" "#{libexec}/bin/sleipnir.mjs" "$@"
      SH
      (bin/name).chmod 0755
    end
  end

  test do
    # `slp ua` lists the UA profiles — no browser, no profile, no side effects.
    assert_match "mac-desktop-chrome", shell_output("#{bin}/slp ua")
  end
end
