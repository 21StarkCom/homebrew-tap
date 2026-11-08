# frozen_string_literal: true

# macOS build of `librarian`, the Atlas vault librarian (`21StarkCom/atlas`, the
# `@atlas/librarian` package): an agent that answers questions from the vaults, over a CLI,
# an MCP server and a daemon. node ESM, like `brain`: the zip ships a `pnpm deploy` tree
# (dist + node_modules). It has no Mach-O of its own; its one Mach-O is the Agent SDK's
# Anthropic-signed `claude`. Released from `librarian-v*` tags by `scripts/release-librarian.sh`.
class Librarian < Formula
  desc "Atlas vault librarian: answers questions from the vaults (CLI, MCP, daemon)"
  homepage "https://github.com/21StarkCom/atlas"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/atlas/releases/assets/725048343",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.14.0"
  sha256 "61620f3e4bd51524a43e28f3b44189e2472e7bcdd2b279c1097f3f8363c06e54"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

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
