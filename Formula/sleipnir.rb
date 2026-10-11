# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of sleipnir — a CLI that drives
# dedicated, persistent Chrome profiles for ad-hoc agent tasks. Bun runs the
# TypeScript directly (no build step), so the zip ships the source tree + vendored
# prod node_modules; the one compiled artifact is the Swift mac-helper.
class Sleipnir < Formula
  desc "Drive dedicated, persistent Chrome profiles for ad-hoc agent tasks"
  homepage "https://github.com/21StarkCom/sleipnir"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/sleipnir/releases/assets/630648248",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.23.0"
  sha256 "c7ab1f3dbdfb6fadf945279ce9d38fc12387cb373a047b58a82f5f7ff6e764d3"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64 # the shipped mac-helper is a signed arm64 Mach-O
  depends_on "bun" # Bun runs the TypeScript directly; sleipnir has no build step
  depends_on :macos # drives system Chrome + a Swift AX/CGEvent helper

  def install
    # The zip is the runnable tree (apps/, packages/, vendored node_modules, and the
    # signed helper at apps/mac-helper/.build/release/mac-helper). The helper is
    # resolved relative to packages/mac/src, so the layout must be kept intact —
    # install the whole tree into libexec and wrap each command's launcher.
    libexec.install Dir["*"]
    # `huginn` is the browser extension's CLI (`huginn <action>` = `slp huginn <action>`), and
    # `sleipnir-mcp` the stdio MCP server an agent client starts from its own working directory.
    # Keep the caller's working directory out of the runtime: by default Bun loads its .env
    # (SLEIPNIR_HOME, CHROME_BINARY, SLEIPNIR_MIMIR_BIN, and for the MCP server
    # SLEIPNIR_MCP_ALLOW_MUTATE, which lifts its mutate-cap gate) and runs its bunfig.toml preloads.
    {
      "sleipnir"     => "apps/sleipnir/bin/sleipnir.mjs",
      "slp"          => "apps/sleipnir/bin/sleipnir.mjs",
      "huginn"       => "apps/huginn/bin/huginn.mjs",
      "sleipnir-mcp" => "apps/mcp/bin/sleipnir-mcp.mjs",
    }.each do |name, entry|
      (bin/name).write <<~SH
        #!/bin/bash
        exec "#{formula_opt_bin("bun")}/bun" --no-env-file --config=/dev/null "#{libexec}/#{entry}" "$@"
      SH
      (bin/name).chmod 0755
    end
  end

  def caveats
    <<~EOS
      sleipnir drives Huginn 0.41.0 or newer, the builds that update themselves (sleipnir
      0.13.0 was the first release to ship one). Each `brew upgrade 21StarkCom/tap/sleipnir`
      reaches every browser running one with no command, once nothing is using the extension
      there: Huginn and Huginn Secrets about six minutes later, Huginn Scan within 30 minutes
      (`slp huginn auto-update off` stops it). A Huginn older than 0.41.0 (any Chrome profile
      not reloaded since sleipnir 0.12.3 or earlier) runs nothing: the host and the CLI refuse
      every request to it, `slp huginn reload` included, and `slp huginn list` marks it
      stale. Run `#{opt_bin}/slp huginn install` once, then press Reload once on Sleipnir
      Huginn (named Sleipnir Companion before Huginn 0.39.0) in each such profile's
      chrome://extensions. That install also rewrites a launcher from sleipnir 0.12.2 or
      earlier, which names the versioned bun and sleipnir kegs.

      0.23.0 ships Huginn 0.61.2 (the update above), whose popup's new Screenshot button
      captures the whole page, whatever it shows of a signed-in account, into
      ~/Documents/Huginn/screenshots/, where its editor saves the JPG or PDF crops beside it.
      Since 0.19.0 Huginn saves everything it makes for you (journeys, recordings, downloads,
      uploads, and now screenshots) in ~/Documents/Huginn/, not SLEIPNIR_HOME's huginn/; macOS
      asks once whether bun may use your Documents folder, and until you allow it Huginn keeps
      saving in SLEIPNIR_HOME's huginn/. Treat ~/Documents/Huginn/ as secret, and turn off
      iCloud Drive's Desktop & Documents Folders to keep it on this Mac.

      0.18.0 removes the old names 0.14.0 deprecated (below), each now refused (exit 2; the
      MCP server returns an error): the 23 old cap names, whose refusal names the new one
      (`slp cap login-google` names `google-login`), though `slp deny <profile> <old name>`
      still revokes the new one, and `slp caps --json` and MCP list_caps drop `aliases`;
      `--force` everywhere but `slp allow` (use `--yes`, `--overwrite` or `--reharvest`);
      `--csv` (use `--worklist`); a `--duration` number with no unit (write `20s` or `500ms`);
      an exported journey script's `--instance` (use `--huginn`); and the MCP arguments
      `instance` on huginn and huginn_batch (`huginn` is now required) and `force` on run_cap.
      Nor does it print the old JSON keys 0.14.0 kept beside the new ones: read `grants`, not
      `allow`, from `huginn list --json`, MCP list_huginns and `huginn allow|deny`; `steps`,
      not `actions`, from a `journey-replay` dry run; and `stepCount`, not a count named
      `steps`, from `huginn record … journey` and `journey-export`. Journeys are now written
      as version 3, which sleipnir 0.14.0 and later read, and replay dry runs and reports give
      a journey's `version` as 3, not 2. The twelve `gl-*` caps are gone too: a grant naming
      one matches nothing, and `slp deny` removes it.

      0.18.0 ships huginn-bridge 0.6.0, the bridge at
      #{opt_libexec}/apps/huginn-bridge/bin/huginn-bridge.mjs.
      It drops `--instance` (use `--huginn`), a `run` request's `"instance"`, `--capabilities`
      (use `--grants`) and `uninstall --dry-run`: its `uninstall` now only shows what it would
      remove unless you pass `--yes`. Its JSON drops the old names too: read `id`, not
      `instance`, from `companions` and `choices`; `huginn` and `grants`, not `instance` and
      `capabilities`, from a session; and `steps` and `requires.grants`, not `actions` and
      `requires.capabilities`, from a `replay` dry run.

      0.18.0's `anthropic-receipts`, and `mesh-receipts-collect` for `anthropic`, read invoices
      only once the claude.ai Team account is confirmed active. A switch that failed or went
      unconfirmed used to read whichever account was active and exit 0; now a login with no
      Team account exits 3, and a switch it cannot confirm exits 4 (3 when the page bounced to
      `claude.ai/login`). `mesh-receipts-collect` lists either in `enumFailures`, which blocks
      `--yes`.

      0.17.3 ships Huginn 0.60.0 (the update above), whose popup's new Chat button opens a
      side panel where a local Claude Code session reads and acts on the tab beside it. It
      runs `idun bob --agent claude` (`brew install 21StarkCom/tap/idun`, and Claude Code
      signed in): no permission prompts, with your settings, hooks and MCP servers, so text on
      a page it reads reaches a session that runs any command without asking. It acts through
      sleipnir-mcp's huginn tools: register #{opt_bin}/sleipnir-mcp with Claude Code at user
      scope (below), and close a chat left open across an upgrade, as you restart MCP clients.
      Its Record session saves a zip through Chrome's downloads (kept in
      ~/Documents/Huginn/chat-recordings/ when it cannot reach the panel) holding the
      replayable journey, a screenshot before and after each action, the conversation and the
      session's context, which keeps every page and command output it saw, secrets included:
      treat those zips, and the panel's two downloads, as secret.

      0.17.1 renames a Huginn or Huginn Secrets installation in your everyday Chrome that
      0.16.1 or 0.17.0 left named after the browser though you had labelled it: macOS keeps
      Chrome's own profile folder from the native host, so there the label set in its popup is
      what names it. It takes that label when its browser next connects, keeping its 6 hex,
      grants, update state and recordings (`slp-huginn-chrome-c17187` labelled "Work Profile"
      becomes `slp-huginn-work-profile-c17187`), and the old ID exits 2 naming the new one:
      update scripts and MCP client configs again from `slp huginn list` and
      `huginn secrets list`. One still named `chrome` or `chrome-canary` takes its label the
      first time it connects with one.

      0.17.0 ships Huginn 0.58.2 (the update above), whose popup records again: press Record,
      work in the tab, then Stop. Each recording, an incomplete one too, is saved as a journey
      file in ~/Documents/Huginn/journeys/<installation id>/ and keeps the text you typed,
      passwords included: treat that folder as secret. The popup's new Recordings page lists,
      loads, deletes and replays them; a Replay pressed there runs live in a new tab with no
      grant and no `--yes`, while `slp cap journey-replay --huginn` and the MCP tools still
      need both.

      0.16.1 names a Huginn or Huginn Secrets installation in a plain Chrome profile after the
      label set in its popup, ahead of Chrome's profile name (in your everyday Chrome on macOS,
      only from 0.17.1, above). An ID 0.16.0 named otherwise than that label, or after the
      browser, is renamed once when its browser next connects, keeping its 6 hex and grants,
      and the old ID exits 2 naming the new one (still in 0.18.0; a later release drops that):
      update scripts and MCP client configs again from `slp huginn list` and
      `huginn secrets list`. An old UUID still answers in 0.18.0 as it did in 0.16.0.

      0.16.0 ships Huginn 0.57.1 and Huginn Secrets 0.8.0 (the update above), which name each
      installation after its browser profile, `slp-huginn-<profile>-<6 hex>` and
      `slp-secrets-<profile>-<6 hex>`, in place of its UUID; it keeps its grants when its
      browser first connects after the update. 0.16.0 refuses an old UUID (exit 2) wherever an
      installation is named (`--huginn`, `huginn secrets`, journey scripts, the MCP tools) and
      names the new ID once that browser has connected; a later release drops even that. Update
      scripts and MCP client configs from `slp huginn list` and `huginn secrets list`; `forget`
      and `deny` still take the UUID of a browser that never reconnects. Huginn 0.57.1's popup
      recorded no demonstration (0.17.0's records again, above); `slp cap journey-record
      --huginn <id> --tab <id> --out <file>` still records one. Its new `evaluate` action runs
      your JavaScript in a tab through the page's signed-in session, once you grant `evaluate`
      and pass `--yes` (MCP `confirm:true`).

      0.15.0 ships Huginn 0.55.1 and Huginn Secrets 0.7.0 (the update above), which refuse
      nothing you could do by hand. Huginn redacts nothing: observe, find and set-value read
      password, one-time-code and card fields like any other, and recordings, demonstrations
      and journeys keep the values you entered, passwords included, which `journey-replay`
      and exported scripts replay: treat journey files and scripts as secrets. Huginn Secrets
      now reads and writes the vault in a browser with remote debugging (`slp cdp`, `open`,
      `run`), and sleipnir registers its native host in every Sleipnir profile it launches
      Chrome on while Secrets is installed: keep loading Secrets only in a browser you sign
      in to by hand. Through the MCP server, `gamma-receipts` now needs `confirm`; a Mimir
      vault that is locked or doesn't answer now exits 3 for every cap that reads it, not 4;
      and a `mesh-receipts-collect --yes` run whose worklist holds a Perplexity (`ENT PRO`)
      charge sends nothing without a live Perplexity session on its profile (`--vendor`
      collects the others).

      0.14.0 renames 23 caps to <service>-<what> (`slp caps` lists the new names:
      `login-google` is now `google-login`, `export-journey` is `journey-export`) and some
      flags: `--yes` deletes and `--overwrite` replaces an `--out` file where `--force` did,
      and the MCP tools huginn and huginn_batch take `huginn` where they took `instance`.
      0.18.0 removes the old names (above). Grants stored under old cap names in profiles.json
      are still rewritten the first time sleipnir reads them (a cap, `cdp`, `open`, `run`,
      `smoke`, `slp caps`, `profiles`, `allow` or `deny`), and an `slp` older than 0.14.0 on
      the same SLEIPNIR_HOME (a checkout not yet pulled) then refuses those caps until it is
      upgraded. Since 0.14.0, under `--json`, the vendor `*-receipts` caps print
      `{ok, invoices}` and `gmail-scan` prints `{ok, messages}`, no longer a bare array.

      Once a browser runs the builds 0.14.0 ships (Huginn 0.49.5, Huginn Scan 0.2.2, Huginn
      Secrets 0.5.4: the update above), each of the three works in incognito windows after
      you turn on Allow in Incognito in its Details in chrome://extensions. Flipping that
      switch reloads the extension, ending whatever it was running. `slp huginn list`,
      `huginn secrets list` and Huginn Scan's popup say when it is off.

      Restart MCP clients after every `brew upgrade 21StarkCom/tap/sleipnir`: a running
      sleipnir-mcp starts each tool call from the keg the upgrade removed. After
      `brew upgrade bun` (or a `brew upgrade` that upgrades it), restart an MCP client still
      running a sleipnir-mcp from sleipnir 0.12.2 or earlier (later versions run tool calls
      through #{formula_opt_bin("bun")}/bun).

      A journey script exported from a Homebrew sleipnir 0.12.2 or earlier imports that
      version's keg, which `brew upgrade 21StarkCom/tap/sleipnir` cleans up: after upgrading
      past 0.12.2, export it again, once, with `slp cap journey-export`, or keep your edits
      by pointing its import at
      #{opt_libexec}/apps/huginn-bridge/src/journey-script.ts. A later version's export
      imports through #{opt_prefix}, which each upgrade points at the new keg.

      Point MCP clients at #{opt_bin}/sleipnir-mcp. A client that runs bun on a
      sleipnir-mcp.mjs in a sleipnir keg's libexec loads its working directory's .env
      (which can set SLEIPNIR_MCP_ALLOW_MUTATE=1) and bunfig.toml preloads: rewire it.

      0.12.0 removed the `companion` aliases: use `slp huginn` or `huginn`, `--huginn <id>`,
      and the MCP tools list_huginns, list_huginn_native_caps, huginn and huginn_batch
      (`run_cap` takes `huginn`, not `companion`).

      0.13.0 adds two extensions beside Huginn, each loaded with Load unpacked, once per Chrome
      profile, from the folders `slp huginn install` prints: Huginn Scan (accessibility scans),
      and Huginn Secrets, which fills and saves Mimir sign-ins and now shows the one-time
      codes Huginn used to. Load Secrets only in a browser you sign in to by hand. Huginn's
      `mimir.authenticator` native capability is gone: use `huginn secrets codes`.
      Huginn Secrets needs Mimir 0.27.0 or newer for codes and fill (`brew upgrade --cask
      21StarkCom/tap/mimir`), and Mimir 0.28.x, with Allow vault writes on, to save: Mimir
      0.29.0's service is read-only, so a save there says "Mímir Service can't save yet: save
      it in the Mímir app." and `huginn secrets collect --yes` exits 3 (4 before 0.17.2).
      Its `huginn secrets` command line also needs the grants you tick in its popup.
    EOS
  end

  test do
    assert_equal version.to_s, JSON.parse((libexec/"package.json").read)["version"]
    # `slp ua` lists the UA profiles — no browser, no profile, no side effects.
    assert_match "mac-desktop-chrome", shell_output("#{bin}/slp ua")
    # `huginn --help` prints its usage without reaching a browser or the native host.
    assert_match "usage: huginn", shell_output("#{bin}/huginn --help")
    # The MCP launcher answers `help` before it imports the server or opens stdio.
    assert_match "Usage: sleipnir-mcp", shell_output("#{bin}/sleipnir-mcp help")
    # `slp huginn install` registers Huginn's native host and Huginn Secrets' own
    # (`com.21stark.huginn.secrets`) with Chrome; `--probe` loads each one's whole module
    # graph from the installed tree without starting a host.
    %w[huginn-host.mjs huginn-secrets-host.mjs].each do |host|
      probe = shell_output("#{formula_opt_bin("bun")}/bun #{libexec}/apps/huginn/bin/#{host} --probe")
      assert_equal true, JSON.parse(probe).fetch("ok")
    end
    # A bunfig.toml preload or .env in the working directory must not reach the wrappers.
    (testpath/"bunfig.toml").write 'preload = ["./preload.ts"]'
    (testpath/"preload.ts").write 'throw new Error("cwd bunfig preload ran")'
    (testpath/".env").write "SLEIPNIR_HOME=#{testpath}/from-dotenv\n"
    assert_match "mac-desktop-chrome", shell_output("#{bin}/slp ua")
    assert_match "usage: huginn", shell_output("#{bin}/huginn --help")
    # `help` returns before the server loads; `initialize` over stdio loads its whole module
    # graph from the installed tree, and the server exits when stdin closes.
    init = { jsonrpc: "2.0", id: 1, method: "initialize",
             params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "brew", version: "0" } } }
    reply = JSON.parse(pipe_output(bin/"sleipnir-mcp", "#{init.to_json}\n", 0))
    assert_equal version.to_s, reply.dig("result", "serverInfo", "version")
    refute_match "from-dotenv", shell_output("#{bin}/slp profile")
  end
end
