# frozen_string_literal: true

require "download_strategy"

# Cask URL specs are serialized by brew info and installed metadata. Keep the
# credential in the downloader only; inherit all native preflight/cache/resume.
class MimirPrivateReleaseStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
    token = GitHub::API.credentials.to_s.strip
    if token.empty?
      raise CurlDownloadStrategyError.new(
        url,
        "This private tap needs a GitHub token with contents:read access: " \
        "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
      )
    end
    @meta[:headers] = ["Accept: application/octet-stream", "Authorization: token #{token}"]
  end
end

# Signed (Developer ID) + notarized + STAPLED macOS build of Mímir — a personal macOS
# credential vault with a paired `mimir` CLI (ADR-0025) and a loopback MCP server for agents.
# A GUI app, so it ships as a cask: the .app lands in /Applications and the nested CLI is
# symlinked onto PATH — the same layout `make install` produces. The zip is the notarized,
# stapled bundle (Mimir.app at the archive root), so Gatekeeper validates it offline.
cask "mimir" do
  # version / asset id / sha256 are release-specific and rewritten when mimir's release
  # calls the bumper (the README's caller table) — do not hand-edit them.
  #
  # `brew audit` warns "Use sha256 :no_check when URL is unversioned" because the version
  # string is not in the (opaque, by-asset-id) URL. We keep a real sha256 anyway, DELIBERATELY:
  # `:no_check` would disable integrity verification on a private download, which is the wrong
  # trade for a credential vault, and the versioned browser-download URL 404s for private-repo
  # assets even with a token (verified) — the API asset id is the only working private fetch.
  version "0.38.0"
  sha256 "044d83f1c6a5bf3ef1f604cbcf5be8aaf3f9b40167e482c032ee340ca3b7abb6"

  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/mimir/releases/assets/650255278",
      using: MimirPrivateReleaseStrategy
  name "Mímir"
  desc "Personal credential vault with a paired CLI and loopback MCP server"
  homepage "https://github.com/21StarkCom/mimir"

  depends_on arch: :arm64        # the shipped bundle is a signed arm64 Mach-O
  depends_on macos: :tahoe       # min macOS 26 (Package.swift .macOS(.v26)); bare symbol == ">="

  app "Mimir.app"
  # The CLI lives INSIDE the bundle and must be reached by a symlink, never a copy: it resolves
  # its own path to find the Mímir Service executable it pins (MimirBundleLayout.servicePin). A
  # copy has no bundle above it, so no pin: it never dials the service's socket, only the opt-in
  # TCP port, unverified.
  binary "#{appdir}/Mimir.app/Contents/Resources/bin/mimir"

  # The app and its menu bar item (Mimir Menu, a login item nested in the bundle); `brew upgrade`
  # reopens both by bundle id (`open -b`). On a Mac holding other copies with these ids (dev
  # builds), LaunchServices may reopen one of those instead: quit both and open the installed
  # Mímir, whose launch opens the menu inside its own bundle by path. Mímir Service needs no
  # directive: it seals when its bundle is replaced and exits once the new one verifies, and
  # launchd relaunches it. Never `launchctl` here: Homebrew runs every `uninstall` directive but
  # `signal` on `brew upgrade` too, so it would boot the service out on every upgrade (mimir's
  # spec 2026-09-25-background-service §5.5).
  uninstall quit: [
    "com.21stark.mimir",
    "com.21stark.mimir.menu",
  ]

  # `brew uninstall --zap` only. Removes the three launchd jobs the app registers, Mímir Service's,
  # the menu bar's login item and Mímir Sync's (the sync helper, registered only while sync is on),
  # which a plain uninstall leaves registered against the deleted bundle. Trashes
  # ~/Code/Temp/Mimir too: the plaintext copy of the whole vault, secrets in the clear, that
  # every schema 2 conversion writes (a schema 1 vault's first unlock under 0.30, or under Mímir
  # Service from 0.31.1, or a schema 1 backup's restore) and Mímir never deletes
  # (PlaintextV1Export.defaultRoot, the service's root too). From 0.31.0 Mímir Service makes its
  # own Drive and AI calls (URLSession.shared), so it keeps a cache and HTTP storage under its own
  # bundle id.
  # Leaves the login-Keychain vault key alone — that crypto-erases the vault and is the app's own
  # Danger Zone → Erase Everything, never a package manager's job.
  zap launchctl: [
        "com.21stark.mimir.menu",
        "com.21stark.mimir.service",
        "com.21stark.mimir.sync",
      ],
      trash:     [
        "~/Code/Temp/Mimir",
        "~/Library/Application Support/.mimir-*",
        "~/Library/Application Support/Mimir",
        "~/Library/Caches/com.21stark.mimir",
        "~/Library/Caches/com.21stark.mimir.service",
        "~/Library/HTTPStorages/com.21stark.mimir",
        "~/Library/HTTPStorages/com.21stark.mimir.service",
        "~/Library/Preferences/com.21stark.mimir.menu.plist",
        "~/Library/Preferences/com.21stark.mimir.plist",
        "~/Library/Saved Application State/com.21stark.mimir.savedState",
      ]

  caveats <<~EOS
    Installing needs GitHub read access to 21StarkCom private repos: Homebrew's gh signed
    in (`brew install gh && gh auth login`), or export HOMEBREW_GITHUB_API_TOKEN=<token>

    Opening Mímir registers Mímir Service, the background helper the `mimir` CLI and MCP
    talk to. Pair the CLI from the Mímir menu bar item (CLI ▸ Pair a CLI…, then
    `mimir pair`); `mimir status` reports the state.

    0.32.0 moves the vault key into Mímir Service's own Keychain item at the first unlock
    after upgrading, with no Keychain dialog; a step that fails shows in the menu bar's Issues
    and is retried at the next unlock. The move is one-way: 0.31.x still opens the vault, but
    a Mímir older than 0.31.0 finds no key item and needs a restore from a backup with your
    recovery key, so keep a recent Drive backup and your recovery key before going back.

    A vault no Mímir 0.30 has unlocked is still at schema 1. From 0.31.1 Mímir Service converts
    it at its first unlock, so upgrading from 0.29.x or older no longer needs a pass through
    0.30.3; if the conversion can't run, the vault stays locked and the lock screen says why.

    0.31.0 makes Mímir Service the vault's one writer. After upgrading, choose Settings ›
    Backup › Connect Google Drive once: the service keeps its own Drive sign-in, so no Drive
    backup runs until you do. Choose Always Allow if macOS asks for the drop-box Keychain item
    at the service's first unlock. CLI writes and `import` work again once Settings › CLI ›
    Allow vault writes is on (off by default); `mimir backup verify` stays off. Lock after
    inactivity now only hides the window behind a Touch ID curtain, and CLI and MCP agents keep
    working; Lock Now, the screen lock and sleep still seal the vault.

    0.31.1 brings back the app's archive Export…, which Mímir Service now builds. Its
    passphrase needs at least 12 characters with some variety (or 16), so a shorter one that
    0.30 accepted is refused.

    0.32.2 brings back `mimir export --sealed` through Mímir Service, with vault writes off
    too. Its archive is not a full backup, even with `--all`: it holds only the current values
    the CLI's doors let it read, and leaves out every 2FA recipe and backup code and all
    history. Use the app's Export… for a full archive.

    0.29.0 and 0.30.0 shipped a stale Google sign-in secret, so every Drive backup failed
    silently (HTTP 401). After upgrading, run Back Up Now in Settings › Backup and check that
    it lists a snapshot dated today; reconnect Google Drive if it asks. From 0.30.3 the menu
    bar item notifies you when a backup fails or falls a day behind: allow its notifications
    when macOS asks, or the alert shows only in the menu and the app.

    Converting a schema 1 vault (its first unlock under 0.30 or 0.31.1 and later, or restoring
    a schema 1 backup) first writes the whole vault, secrets included and unencrypted, to a
    folder under ~/Code/Temp/Mimir that Mímir never deletes (Settings › General › Plaintext
    export shows it): delete it once you have checked your items. `mimir label` replaces
    `mimir folder`, `folders` and `tag`.

    0.29.0 moved the CLI, MCP and the drop box into Mímir Service. After upgrading from 0.28.0
    or older, allow Mímir Service in Login Items if macOS asks, choose Always Allow on its
    Keychain dialogs, and pair the CLI again (above).

    A plain `brew uninstall` leaves Mímir Service and the menu bar's login item registered
    with launchd; stop the service with
    `launchctl bootout gui/$(id -u)/com.21stark.mimir.service`.
    `brew uninstall --zap --cask 21StarkCom/tap/mimir` removes both AND moves Mímir's local
    data, the vault and its plaintext export included, to the Trash (add `--force` once a
    plain uninstall has run).
  EOS
end
