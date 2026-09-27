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
  url "https://api.github.com/repos/21StarkCom/sleipnir/releases/assets/592179420",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.11.0"
  sha256 "c41693d166f47a07179fbcfc3cf1b27edf52368ee1992f4d98cfdab54269dd07"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64 # the shipped mac-helper is a signed arm64 Mach-O
  depends_on "bun" # Bun runs the TypeScript directly; sleipnir has no build step
  depends_on :macos # drives system Chrome + a Swift AX/CGEvent helper

  def install
    # The zip is the runnable tree (apps/, packages/, vendored node_modules, and the
    # signed helper at apps/mac-helper/.build/release/mac-helper). The helper is
    # resolved relative to packages/mac/src, so the layout must be kept intact —
    # install the whole tree into libexec and wrap each command's launcher.
    libexec.install Dir["*"]
    # `huginn` is the browser extension's CLI (`huginn <action>` = `slp huginn <action>`).
    # Keep the caller's working directory out of the runtime: by default Bun loads its
    # .env (SLEIPNIR_HOME, CHROME_BINARY, SLEIPNIR_MIMIR_BIN) and runs its bunfig.toml preloads.
    {
      "sleipnir" => "apps/sleipnir/bin/sleipnir.mjs",
      "slp"      => "apps/sleipnir/bin/sleipnir.mjs",
      "huginn"   => "apps/huginn/bin/huginn.mjs",
    }.each do |name, entry|
      (bin/name).write <<~SH
        #!/bin/bash
        exec "#{formula_opt_bin("bun")}/bun" --no-env-file --config=/dev/null "#{libexec}/#{entry}" "$@"
      SH
      (bin/name).chmod 0755
    end
  end

  def caveats
    <<~EOS
      After `brew upgrade 21StarkCom/tap/sleipnir` or `brew upgrade bun`, re-run `slp huginn install`
      and reload the Sleipnir Huginn extension (named Sleipnir Companion before Huginn 0.39.0)
      in each Chrome profile.

      MCP clients wired to #{opt_libexec}/bin/sleipnir-mcp.mjs (0.10.0 and older)
      must point at #{opt_libexec}/apps/mcp/bin/sleipnir-mcp.mjs.

      The Huginn Authenticator tab additionally needs Mimir 0.27.0 or newer
      (`brew upgrade --cask 21StarkCom/tap/mimir`) plus a per-installation grant.
    EOS
  end

  test do
    assert_equal version.to_s, JSON.parse((libexec/"package.json").read)["version"]
    # `slp ua` lists the UA profiles — no browser, no profile, no side effects.
    assert_match "mac-desktop-chrome", shell_output("#{bin}/slp ua")
    # `huginn --help` prints its usage without reaching a browser or the native host.
    assert_match "usage: huginn", shell_output("#{bin}/huginn --help")
    # The MCP launcher answers `help` before it imports the server or opens stdio.
    assert_match "Usage: sleipnir-mcp",
                 shell_output("#{formula_opt_bin("bun")}/bun #{libexec}/apps/mcp/bin/sleipnir-mcp.mjs help")
    # `slp huginn install` registers this native host with Chrome; `--probe` loads its
    # whole module graph from the installed tree without starting a host.
    host = "#{libexec}/apps/huginn/bin/huginn-host.mjs"
    assert_equal true, JSON.parse(shell_output("#{formula_opt_bin("bun")}/bun #{host} --probe")).fetch("ok")
    # A bunfig.toml preload or .env in the working directory must not reach the wrappers.
    (testpath/"bunfig.toml").write 'preload = ["./preload.ts"]'
    (testpath/"preload.ts").write 'throw new Error("cwd bunfig preload ran")'
    (testpath/".env").write "SLEIPNIR_HOME=#{testpath}/from-dotenv\n"
    assert_match "mac-desktop-chrome", shell_output("#{bin}/slp ua")
    assert_match "usage: huginn", shell_output("#{bin}/huginn --help")
    refute_match "from-dotenv", shell_output("#{bin}/slp profile")
  end
end
