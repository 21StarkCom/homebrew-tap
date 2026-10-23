# frozen_string_literal: true

# macOS build of `odinctl` (`21StarkCom/odin`, the `@21starkcom/odinctl` package): the doors
# that run a playbook on the odin agent kernel, from a terminal (`odinctl run`) or on a schedule
# (`odinctl schedule`, which writes its own launchd plists, so this formula has no service block).
# node ESM, like `librarian`: the zip ships an `npm install --install-links` tree (dist +
# node_modules + conformance). It has no Mach-O of its own; its one Mach-O is the Agent SDK's
# Anthropic-signed `claude`. Released from `odinctl-v*` tags by `scripts/release-odinctl.sh`.
# The formula is `odinctl`, not `odin`: homebrew/core's `odin` is the Odin language compiler.
class Odinctl < Formula
  desc "Doors that run a playbook on the odin agent kernel (terminal and schedule)"
  homepage "https://github.com/21StarkCom/odin"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/odin/releases/assets/668322606",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.0"
  sha256 "14675dc7bf6ba3d33e798d227833f3c939e9ea462d97e374d66cee8b1ff0a2e6"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64 # the Agent SDK's vendored `claude` is darwin-arm64
  depends_on :macos
  depends_on "node" # odinctl is node ESM; the keg node runs dist/bin.js

  def install
    # The zip is the runnable tree (dist/, node_modules/ with no symlinks, conformance/,
    # package.json). odinctl reads its conformance fixtures from libexec/conformance, so keep
    # the layout intact under libexec and wrap the entry point.
    libexec.install Dir["*"]
    (bin/"odinctl").write <<~SH
      #!/bin/bash
      exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"
    SH
    (bin/"odinctl").chmod 0755
  end

  test do
    # `odinctl --version` prints the version; assert it against the formula's version —
    # version-agnostic, never a hardcoded string.
    assert_match version.to_s, shell_output("#{bin}/odinctl --version")
    # Every run starts the SDK's vendored `claude`, found beside the SDK as node finds it.
    sdk = (libexec/"node_modules/@anthropic-ai/claude-agent-sdk").realpath
    assert_match "(Claude Code)", shell_output("#{sdk.parent}/claude-agent-sdk-darwin-arm64/claude --version")
  end
end
