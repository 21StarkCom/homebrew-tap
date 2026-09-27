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
  url "https://api.github.com/repos/21StarkCom/sleipnir/releases/assets/593583955",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.12.2"
  sha256 "3702b591265c400332aa29fcf7e8be0e5d39c4e9574884805e0edf0abe55c938"
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
    # `huginn` is the browser extension's CLI (`huginn <action>` = `slp huginn <action>`), and
    # `sleipnir-mcp` the stdio MCP server an agent client starts from its own working directory.
    # Keep the caller's working directory out of the runtime: by default Bun loads its .env
    # (SLEIPNIR_HOME, CHROME_BINARY, SLEIPNIR_MIMIR_BIN, and for the MCP server
    # SLEIPNIR_MCP_ALLOW_MUTATE, which lifts its mutate-cap gate) and runs its bunfig.toml preloads.
    {
      "sleipnir"     => "apps/sleipnir/bin/sleipnir.mjs",
      "slp"          => "apps/sleipnir/bin/sleipnir.mjs",
      "huginn"       => "apps/huginn/bin/huginn.mjs",
      "sleipnir-mcp" => "apps/mcp/bin/sleipnir-mcp.mjs",
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
      After `brew upgrade 21StarkCom/tap/sleipnir` or `brew upgrade bun`, re-run `slp huginn install`,
      reload the Sleipnir Huginn extension (named Sleipnir Companion before Huginn 0.39.0)
      in each Chrome profile, and restart MCP clients: a running sleipnir-mcp starts each
      tool call from the keg the upgrade removed.

      A journey script exported by `slp cap export-journey` from a Homebrew sleipnir 0.12.2
      or earlier imports that version's keg, which `brew upgrade 21StarkCom/tap/sleipnir`
      cleans up: after upgrading past 0.12.2, export it again, once, or keep your edits by
      pointing its import at #{opt_libexec}/apps/huginn-bridge/src/journey-script.ts.
      A later version's export imports through #{opt_prefix}, which each upgrade points at
      the new keg.

      Point MCP clients at #{opt_bin}/sleipnir-mcp. A client that runs bun on a
      sleipnir-mcp.mjs in a sleipnir keg's libexec loads its working directory's .env
      (which can set SLEIPNIR_MCP_ALLOW_MUTATE=1) and bunfig.toml preloads: rewire it.

      0.12.0 removed the `companion` aliases: use `slp huginn` or `huginn`, `--huginn <uuid>`,
      and the MCP tools list_huginns, list_huginn_native_caps, huginn and huginn_batch
      (`run_cap` takes `huginn`, not `companion`).

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
    assert_match "Usage: sleipnir-mcp", shell_output("#{bin}/sleipnir-mcp help")
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
    # `help` returns before the server loads; `initialize` over stdio loads its whole module
    # graph from the installed tree, and the server exits when stdin closes.
    init = { jsonrpc: "2.0", id: 1, method: "initialize",
             params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "brew", version: "0" } } }
    reply = JSON.parse(pipe_output("#{bin}/sleipnir-mcp", "#{init.to_json}\n", 0))
    assert_equal version.to_s, reply.dig("result", "serverInfo", "version")
    refute_match "from-dotenv", shell_output("#{bin}/slp profile")
  end
end
