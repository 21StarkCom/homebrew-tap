require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class SleipnirGitHubPrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private sleipnir tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Signed (Developer ID) + notarized macOS build of sleipnir — a CLI that drives
# dedicated, persistent Chrome profiles for ad-hoc agent tasks. Bun runs the
# TypeScript directly (no build step), so the zip ships the source tree + vendored
# prod node_modules; the one compiled artifact is the Swift mac-helper.
class Sleipnir < Formula
  desc "Drive dedicated, persistent Chrome profiles for ad-hoc agent tasks"
  homepage "https://github.com/21StarkCom/sleipnir"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/sleipnir/releases/assets/521207061",
      using: SleipnirGitHubPrivateReleaseStrategy
  version "0.2.0"
  sha256 "f7e9b888dc0e28c324809a2f96d4f514e42c11019a8367d899fb35b55eac6a1f"
  depends_on arch: :arm64 # the shipped mac-helper is a signed arm64 Mach-O
  depends_on :macos # drives system Chrome + a Swift AX/CGEvent helper
  depends_on "bun" # Bun runs the TypeScript directly; sleipnir has no build step

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
