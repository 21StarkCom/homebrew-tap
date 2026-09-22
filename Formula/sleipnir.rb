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
  url "https://api.github.com/repos/21StarkCom/sleipnir/releases/assets/581237670",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.10.0"
  sha256 "2f2152f8ecdbb330ccdc28276647843a719c48a585833cece803a858465680f3"
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

  def caveats
    <<~EOS
      After `brew upgrade sleipnir` or `brew upgrade bun`, re-run `slp companion install`
      and reload the Sleipnir Companion extension in each Chrome profile.

      The Companion Authenticator tab additionally needs Mimir 0.27.0 or newer
      (`brew upgrade --cask 21StarkCom/tap/mimir`) plus a per-installation grant.
    EOS
  end

  test do
    assert_equal version.to_s, JSON.parse((libexec/"package.json").read)["version"]
    # `slp ua` lists the UA profiles — no browser, no profile, no side effects.
    assert_match "mac-desktop-chrome", shell_output("#{bin}/slp ua")
    # The MCP launcher answers `help` before it imports the server or opens stdio.
    assert_match "Usage: sleipnir-mcp",
                 shell_output("#{formula_opt_bin("bun")}/bun #{libexec}/bin/sleipnir-mcp.mjs help")
  end
end
