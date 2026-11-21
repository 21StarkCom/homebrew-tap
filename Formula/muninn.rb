# frozen_string_literal: true

# muninn: cross-agent messaging for CLI agents over one local SQLite file.
# It started from agmsg (MIT license, by Koichi Fujikawa).
# The release asset is the tagged bash tree (no Mach-O), built by muninn's release.yml.
# `muninn-install` runs its install.sh, which copies the skill into ~/.agents/skills/muninn/.
class Muninn < Formula
  desc "Cross-agent messaging for CLI agents over local SQLite"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/muninn
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/muninn-v0.3.2/muninn-v0.3.2.tar.gz"
  version "0.3.2"
  sha256 "b2b1df784a805773db8d9f6b92a05f4896c5205f870c86be228e6f20881bc1b8"

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
