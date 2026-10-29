# frozen_string_literal: true

# macOS arm64 build of lucius — a terminal brainstorming partner on the Claude
# Agent SDK. The zip ships minified Bun bundles at the .ts paths this formula
# names, plus their run-time files and the vendored prod node_modules. Its one
# Mach-O is the SDK's own Anthropic-signed `claude` binary
# (@anthropic-ai/claude-agent-sdk-darwin-arm64).
class Lucius < Formula
  desc "Brainstorming partner with the capabilities of a second brain"
  homepage "https://github.com/21StarkCom/lucius"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/lucius/releases/assets/687752727",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.13.0"
  sha256 "469889fd8f4f147c12601b4c9cc712aa3b16a352d5971e9e8b5709d9671cf235"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64 # the vendored SDK `claude` binary is an arm64 Mach-O
  depends_on "bun" # Bun runs the minified bundles that lucius's release builds
  depends_on :macos # vault publication compiles a Darwin-only C shim through bun:ffi

  def install
    # The zip is the runnable tree: minified bundles at bin/lucius.ts,
    # src/session/runtime.ts and src/vault/publication.ts, their run-time files
    # (package.json, bun.lock, src/personas/, src/web/dist/, the src/vault/*.c
    # shims) and the vendored prod node_modules. The bundles find those files
    # from the package root, which holds package.json, and the SDK resolves its
    # `claude` binary from node_modules, so the layout must be kept intact:
    # install the whole tree into libexec and wrap the entry.
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
    assert_equal 1, help.fetch("schemaVersion")
    assert_equal "completed", help.fetch("status")
    assert_equal version.to_s, help.fetch("version")
    assert_match "Usage: lucius", help.fetch("reply")
    # Session startup's own gates, with no session: the Bun floor and the pinned
    # SDK (assertRuntime), and both C shims compiling from the installed tree: the
    # vault publisher, and the fleet listing that an OpenAI or Gemini Lucius or
    # roundtable seat compiles against the macOS SDK headers.
    (testpath/"runtime.ts").write <<~TS
      import { assertRuntime } from "#{libexec}/src/session/runtime.ts"
      import { assertFleetListingSupport, assertPublicationSupport } from "#{libexec}/src/vault/publication.ts"
      await assertRuntime()
      assertPublicationSupport()
      assertFleetListingSupport()
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
