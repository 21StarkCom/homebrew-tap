# frozen_string_literal: true

# macOS build of `odinctl` (`21StarkCom/odin`, the `@21starkcom/odinctl` package): the doors
# that run a playbook on the odin agent kernel, from a terminal (`odinctl run`) or on a schedule
# (`odinctl schedule`, which writes its own launchd plists, so this formula has no service block).
# node ESM, like `librarian`: the zip ships an `npm install --install-links` tree (dist +
# node_modules + conformance + bin). Three Mach-O files: the Agent SDK's Anthropic-signed
# `claude`; odin's face, `bin/odin-face`, the Go program `odinctl ui` starts (from 0.3.0); and
# odin's IT desk, `bin/desk`, the Go program `odinctl desk` and its desk rows run (from 0.30.0).
# The release builds the face and the desk and signs both with the operator's Developer ID.
# Released from `odinctl-v*` tags by `scripts/release-odinctl.sh`.
# The formula is `odinctl`, not `odin`: homebrew/core's `odin` is the Odin language compiler.
# It also installs `odin`, a link to `odinctl`.
class Odinctl < Formula
  desc "Doors that run a playbook on the odin agent kernel (terminal and schedule)"
  homepage "https://github.com/21StarkCom/odin"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/odin/releases/assets/775731438",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.62.0"
  sha256 "5a0be8da4530f7d2d28d2bc217516fa417567c56f6a45c2d6e74d3cbf7f4e1f4"
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

  conflicts_with "odin", because: "both install an `odin` binary"

  def install
    # The zip is the runnable tree (dist/, bin/, conformance/, package.json, and a node_modules/
    # with no symlinks). odinctl reads its conformance fixtures from libexec/conformance, so keep
    # the layout intact under libexec and wrap the entry point.
    libexec.install Dir["*"]
    (bin/"odinctl").write <<~SH
      #!/bin/bash
      exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"
    SH
    (bin/"odinctl").chmod 0755
    bin.install_symlink bin/"odinctl" => "odin"
  end

  test do
    # `odinctl --version` prints `odinctl <version>`; assert it against the formula's version —
    # version-agnostic, never a hardcoded string.
    assert_equal "odinctl #{version}", shell_output("#{bin}/odinctl --version").strip
    assert_equal "odinctl #{version}", shell_output("#{bin}/odin --version").strip
    # `odinctl ui` starts the face beside the shim, at libexec/bin/odin-face; it names its release.
    assert_equal "odin-face #{version}", shell_output("#{libexec}/bin/odin-face --version").strip
    # Every run starts the SDK's vendored `claude`, found beside the SDK as node finds it.
    sdk = (libexec/"node_modules/@anthropic-ai/claude-agent-sdk").realpath
    assert_match "(Claude Code)", shell_output("#{sdk.parent}/claude-agent-sdk-darwin-arm64/claude --version")
  end
end
