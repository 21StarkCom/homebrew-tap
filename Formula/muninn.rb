# frozen_string_literal: true

# muninn, the fleet's copy of agmsg: cross-agent messaging for CLI agents over
# one local SQLite file. The release asset is the tagged bash tree (no Mach-O),
# built by muninn's release.yml. `muninn-install` runs its install.sh, which
# copies the skill into ~/.agents/skills/<cmd>/.
class Muninn < Formula
  desc "Cross-agent messaging for CLI agents over local SQLite (fleet copy of agmsg)"
  homepage "https://github.com/21StarkCom/muninn"
  # version / asset id / sha256 are release-specific and rewritten when muninn's
  # release.yml calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/muninn/releases/assets/720759701",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.0"
  sha256 "7ee29650866514d137be59b5bed9ffd12d04bb81206e264cb7c3fe4f24ec3e2b"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    libexec.install Dir["*"]
    (bin/"muninn-install").write <<~SH
      #!/bin/bash
      exec /usr/bin/env bash "#{libexec}/install.sh" "$@"
    SH
  end

  def caveats
    <<~EOS
      First install: `muninn-install --cmd agmsg` copies the skill into ~/.agents/skills/agmsg/.
      After each `brew upgrade`, run `muninn-install --cmd agmsg --update`: it stops agmsgd,
      updates the scripts, keeps your teams and starts agmsgd again. `brew upgrade` alone does
      not change the installed skill. Before `brew uninstall`, run
      `bash ~/.agents/skills/agmsg/uninstall.sh` to remove the skill.
    EOS
  end

  test do
    assert_equal version.to_s, (libexec/"VERSION").read.strip
    assert_match "--cmd", shell_output("#{bin}/muninn-install --help")
  end
end
