# frozen_string_literal: true

# macOS build of `librarian`, the Atlas vault librarian (`21StarkCom/atlas`, the
# `@atlas/librarian` package): an agent that answers questions from the vaults, over a CLI,
# an MCP server and a daemon. node ESM, like `brain`: the zip ships a `pnpm deploy` tree
# (dist + node_modules). It has no Mach-O of its own; its one Mach-O is the Agent SDK's
# Anthropic-signed `claude`. Released from `librarian-v*` tags by `scripts/release-librarian.sh`.
class Librarian < Formula
  desc "Atlas vault librarian: answers questions from the vaults (CLI, MCP, daemon)"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/atlas
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/librarian-v0.29.0/librarian_0.29.0_darwin_arm64.zip"
  version "0.29.0"
  sha256 "3c7dcef63f11075a87941220b8ce7301b9c871072395a993b776658e1ff4b5cf"

  # The librarian's tools run `brain`. Tap-qualified: a bare name resolves to homebrew/core first,
  # and is ambiguous when another tap ships a `brain`.
  depends_on "21starkcom/tap/brain"
  depends_on arch: :arm64 # the Agent SDK's vendored `claude` is darwin-arm64
  # `librarian harvest` and the daemon's nightly harvest scan each message with `gitleaks stdin`,
  # and refuse without it
  depends_on "gitleaks"
  depends_on :macos
  depends_on "node" # librarian is node ESM; the keg node runs dist/bin.js

  def install
    # The zip is the runnable pnpm-deploy tree (dist/, node_modules/ with relative
    # workspace symlinks, package.json). Keep the layout intact under libexec and wrap
    # the entry point.
    libexec.install Dir["*"]
    (bin/"librarian").write <<~SH
      #!/bin/bash
      exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"
    SH
    (bin/"librarian").chmod 0755
  end

  def caveats
    <<~EOS
      After an upgrade, restart the daemon so it runs the new version:
        brew services restart librarian
    EOS
  end

  service do
    run [opt_bin/"librarian", "daemon"]
    keep_alive true
    # A LaunchAgent's default PATH lacks /opt/homebrew/bin, where `brain` and `mimir` live.
    environment_variables PATH: std_service_path_env
    # The daemon logs to stderr. Its `daemon-unreachable` error says to read `<state>/logs/`.
    log_path "~/.local/state/atlas/librarian/logs/daemon.log"
    error_log_path "~/.local/state/atlas/librarian/logs/daemon.log"
  end

  test do
    # `librarian version` prints the version; assert it against the formula's version —
    # version-agnostic, never a hardcoded string.
    assert_match version.to_s, shell_output("#{bin}/librarian version")
    # Every session starts the SDK's vendored `claude`, found beside the SDK as node finds it.
    sdk = (libexec/"node_modules/@anthropic-ai/claude-agent-sdk").realpath
    assert_match "(Claude Code)", shell_output("#{sdk.parent}/claude-agent-sdk-darwin-arm64/claude --version")
  end
end
