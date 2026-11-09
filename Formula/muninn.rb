# frozen_string_literal: true

# muninn: cross-agent messaging for CLI agents over one local SQLite file.
# It started from agmsg (MIT license, by Koichi Fujikawa).
# The release asset is the tagged bash tree (no Mach-O), built by muninn's release.yml.
# `muninn-install` runs its install.sh, which copies the skill into ~/.agents/skills/muninn/.
class Muninn < Formula
  desc "Cross-agent messaging for CLI agents over local SQLite"
  homepage "https://github.com/21StarkCom/muninn"
  # version / asset id / sha256 are release-specific and rewritten when muninn's
  # release.yml calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/muninn/releases/assets/726777728",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.3.2"
  sha256 "b2b1df784a805773db8d9f6b92a05f4896c5205f870c86be228e6f20881bc1b8"
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
    # Copy, do not move. After install, Homebrew moves CHANGELOG.md, LICENSE and README.md
    # from the build directory to the keg root, and scans libexec for them only when the
    # build directory had none. A copy keeps them in the build directory, so libexec keeps
    # its own CHANGELOG.md, which install.sh reads. The test below catches a regression.
    libexec.mkpath
    cp_r Dir["*"], libexec
    (bin/"muninn-install").write <<~SH
      #!/bin/bash
      exec /usr/bin/env bash "#{libexec}/install.sh" "$@"
    SH
  end

  def caveats
    <<~EOS
      First install: `muninn-install` copies the skill into ~/.agents/skills/muninn/.
      After each `brew upgrade`, run `muninn-install --update`: it stops muninnd,
      updates the scripts, keeps your teams and starts muninnd again. `brew upgrade` alone does
      not change the installed skill. Before `brew uninstall`, run
      `bash ~/.agents/skills/muninn/uninstall.sh` to remove the skill.
      An install made under the old name agmsg moves to muninn on the next `muninn-install` run.
      Until it moves, its uninstall.sh stays in the folder of the old name.
    EOS
  end

  test do
    assert_equal version.to_s, (libexec/"VERSION").read.strip
    assert_match "--cmd", shell_output("#{bin}/muninn-install --help")
    (testpath/".claude").mkpath
    system bin/"muninn-install", "--cmd", "brewtest"
    assert_equal version.to_s, (testpath/".agents/skills/brewtest/VERSION").read.strip
    assert_path_exists testpath/".claude/commands/brewtest.md"
  end
end
