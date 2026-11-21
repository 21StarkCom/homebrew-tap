# frozen_string_literal: true

# Developer-ID-signed (not notarized) macOS build of agent-seats (bun build --compile):
# several Claude Code and Codex logins on one Mac, the daemon that rotates them, and
# the seat-login CLI. The Developer ID keeps Keychain grants across upgrades.
class AgentSeats < Formula
  desc "Claude Code and Codex logins on one Mac: rotation, live usage, one daemon"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/agent-seats
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/agent-seats-v0.38.3/agent-seats_v0.38.3_darwin_arm64.zip"
  version "0.38.3"
  sha256 "7a983cc96ef39be34b31d90739e795a1e87ed9ac2e11f97378b3c2c0c319a092"

  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "agent-seats", "seat-login"
    libexec.install "seat-login-extension"
  end

  # Chrome keeps an unpacked extension's real path, symlinks resolved, and `brew cleanup`
  # deletes each old keg. So the keg's copy stays in libexec, which brew does not link into
  # the prefix, and the extension goes to a folder outside the Cellar. The remove comes
  # first: cp_r into a folder that exists copies into it, and old files would stay.
  post_install_steps do
    remove "seat-login/extension", base: :var, recursive: true
    copy "seat-login-extension", "seat-login/extension", source_base: :libexec, target_base: :var, recursive: true
  end

  def caveats
    <<~EOS
      To run the daemon at login, register it once:
        agent-seats daemon install
      After an upgrade, restart the daemon so it runs the new binary:
        agent-seats daemon restart

      The Seat login Chrome extension is in #{var}/seat-login/extension.
      Load it once: chrome://extensions, turn on Developer mode, Load unpacked, that folder.
      For the seat-login CLI and Codex sign-in, register its native host once, then reload the extension:
        seat-login install
      After an upgrade, click Reload on the extension's card.
    EOS
  end

  test do
    require "digest"
    require "json"

    assert_equal version.to_s, shell_output("#{bin}/agent-seats --version").strip
    assert_match "seat-login", shell_output("#{bin}/seat-login --help")
    # Chrome derives the ID from the key, and the extension's Google sign-in accepts only this ID.
    key = JSON.parse((libexec/"seat-login-extension/manifest.json").read).fetch("key")
    assert_equal "aebjndckmgdgcaonijggcimahgkkfdfd",
                 Digest::SHA256.hexdigest(key.unpack1("m"))[0, 32].tr("0-9a-f", "a-p")
    # The folder Chrome loads is this version's copy: a failed or skipped post-install fails here.
    system "diff", "-r", libexec/"seat-login-extension", var/"seat-login/extension"
  end
end
