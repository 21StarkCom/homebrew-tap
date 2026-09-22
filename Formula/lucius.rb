# frozen_string_literal: true

# macOS arm64 build of lucius — a terminal brainstorming partner on the Claude
# Agent SDK. Bun runs the TypeScript directly (no build step), so the zip ships
# the source tree + vendored prod node_modules. Its one Mach-O is the SDK's own
# Anthropic-signed `claude` binary (@anthropic-ai/claude-agent-sdk-darwin-arm64).
class Lucius < Formula
  desc "Brainstorming partner with the capabilities of a second brain"
  homepage "https://github.com/21StarkCom/lucius"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/lucius/releases/assets/582062887",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.2.0"
  sha256 "f76bde694281c787c97e765205d3a600547e445cdd5c47a68d2d7d620e8da681"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64 # the vendored SDK `claude` binary is an arm64 Mach-O
  depends_on "bun" # Bun runs the TypeScript directly; lucius has no build step
  depends_on :macos # vault publication compiles a Darwin-only C shim through bun:ffi

  def install
    # The zip is the runnable tree (bin/, src/, package.json, bun.lock, vendored
    # node_modules). src/vault/publication.ts compiles ./publication.c beside it,
    # and the SDK resolves its `claude` binary from node_modules, so the layout
    # must be kept intact: install the whole tree into libexec and wrap the entry.
    libexec.install Dir["*"]
    # Keep the caller's working directory out of the runtime: by default Bun
    # loads its .env into process.env and runs its bunfig.toml preloads in-process.
    (bin/"lucius").write <<~SH
      #!/bin/bash
      exec "#{formula_opt_bin("bun")}/bun" --no-env-file --config=/dev/null "#{libexec}/bin/lucius.ts" "$@"
    SH
    (bin/"lucius").chmod 0755
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/lucius --version").strip
    assert_match "Usage: lucius", shell_output("#{bin}/lucius --help")
    # The installed one-shot interface must emit parseable versioned JSON,
    # including its alias, without needing config, credentials or a model call.
    result = JSON.parse(shell_output("#{bin}/lucius --json --version"))
    assert_equal 1, result.fetch("schemaVersion")
    assert_equal "completed", result.fetch("status")
    assert_equal version.to_s, result.fetch("version")
    assert_equal version.to_s, result.fetch("reply")
    help = JSON.parse(shell_output("#{bin}/lucius --porcelain --help"))
    assert_match "Usage: lucius", help.fetch("reply")
    # Session startup's own gates, with no session: the Bun floor and the pinned
    # SDK (assertRuntime), and the C shim compiling from the installed tree.
    (testpath/"runtime.ts").write <<~TS
      import { assertRuntime } from "#{libexec}/src/session/runtime.ts"
      import { assertPublicationSupport } from "#{libexec}/src/vault/publication.ts"
      await assertRuntime()
      assertPublicationSupport()
      console.log("runtime ok")
    TS
    # Same isolation flags as the wrapper, so this gate cannot be swayed by a
    # stray .env or bunfig.toml in testpath (one is seeded below).
    assert_equal "runtime ok", shell_output(
      "#{formula_opt_bin("bun")}/bun --no-env-file --config=/dev/null #{testpath}/runtime.ts",
    ).strip
    # Every session starts the SDK's vendored `claude`; it must survive the install runnable.
    assert_match "(Claude Code)",
                 shell_output("#{libexec}/node_modules/@anthropic-ai/claude-agent-sdk-darwin-arm64/claude --version")
    # A bunfig.toml preload in the working directory must not run inside lucius.
    (testpath/"bunfig.toml").write 'preload = ["./preload.ts"]'
    (testpath/"preload.ts").write 'throw new Error("cwd bunfig preload ran")'
    assert_equal version.to_s, shell_output("#{bin}/lucius --version").strip
  end
end
