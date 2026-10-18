# homebrew-tap

Private [Homebrew](https://brew.sh) tap for the 21Stark fleet, referenced by brew as
`21StarkCom/tap`. It puts the fleet's tools on an Apple Silicon Mac with one
`brew install`: 13 formulae for the CLIs and 3 casks for the GUI apps, each a signed
macOS arm64 build pulled from a private GitHub Release, plus `hermod-linux` and
`frigg-linux`, hermod's and frigg's Linux x86_64 builds for the devbox. The tap builds
nothing. It only pins each entry to a published release, and each source repo's release
re-pins its own entry by pull request.

**Status:** active. Every entry installs today; 16 of the 18 are re-pinned on each release
of their source repo, and the other two are named under
[How it fits the fleet](#how-it-fits-the-fleet). Contributors: the rules for editing an
entry, running the bumper and verifying a change are in [CLAUDE.md](CLAUDE.md).

## In the saga

Pens and pictures reach the operator's hands through [homebrew-tap](https://github.com/21StarkCom/homebrew-tap), the house's private Homebrew tap and home of the one bumper script that source repos' releases run to re-pin their entries by pull request. It appears in [plume](https://github.com/21StarkCom/plume)'s chapter of [The Saga of House Stark](https://github.com/21StarkCom/.github/blob/main/fleet/saga.md).

---

## Install

```sh
# A GitHub token with contents:read on the private 21StarkCom release repos: a
# Homebrew-installed gh signed in to an account that can read them is enough.
brew install gh && gh auth login        # or: export HOMEBREW_GITHUB_API_TOKEN=<token>
# Once, in the foreground, so ssh can ask to trust github.com's host key: answer
# yes only on GitHub's published key fingerprint (below). Exits 1 on success.
ssh -T git@github.com
# Once. The tap repo is private too, so clone it over SSH with your own GitHub key.
brew tap 21StarkCom/tap git@github.com:21StarkCom/homebrew-tap.git
brew install 21StarkCom/tap/<formula>
brew install --cask 21StarkCom/tap/<cask>
brew upgrade 21StarkCom/tap/<name>
```

The token authenticates the release downloads only. Each entry takes it from Homebrew's
own lookup: `HOMEBREW_GITHUB_API_TOKEN` if set, else `gh auth token` (Homebrew's own gh
only: a gh installed another way is not on the path it searches), else a GitHub token
in the macOS keychain. Every `brew` command that reads a formula needs one, `brew info`
included: a formula refuses to evaluate without it. A cask needs it only to download.
Homebrew's sandboxed build and test workers cannot read gh's config, and never download,
so they skip that check. A formula's files are installed without the
quarantine xattr, so an ad-hoc-signed build runs under Homebrew but hits Gatekeeper if you
unzip the release by hand. Casks install their apps quarantined. Every entry but
`hermod-linux` and `frigg-linux` is **macOS arm64 only**; for another platform, build from
the tool's own repo where it supports one (the frigg, lumiere, plume and stark-statusline
sections say how).

`ssh -T git@github.com` makes the Mac's first SSH connection to github.com in a terminal
you watch. Where `~/.ssh/known_hosts` does not hold github.com yet, it asks whether to
trust GitHub's host key: answer `yes` only when the fingerprint it prints matches one of
[GitHub's published SSH key fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).
It then greets you by GitHub username and exits 1, which is expected. Skip it and
`brew tap` hangs with nothing printed: Homebrew runs its clone in a process group of its
own, which stops when ssh asks that question. `gh auth login` can upload your key, but it
does not record GitHub's host key.

## Entries

| Entry | Kind | Source repo | Installs | Build | Signing | macOS |
|---|---|---|---|---|---|---|
| `alfred` | formula | [alfred](https://github.com/21StarkCom/alfred) | `alfred`, `alfredd` | Go | Developer ID + notarized | any |
| `bragi` | formula | [bragi](https://github.com/21StarkCom/bragi) | `bragi`, `bragi-audio` | Go + a Swift helper | Developer ID + notarized | 15 (Sequoia) |
| `brain` | formula | [atlas](https://github.com/21StarkCom/atlas) | `brain` | node ESM tree | Developer ID + notarized native modules | any |
| `frigg` | formula | [frigg](https://github.com/21StarkCom/frigg) | `frigg`, `frigg-cockpit`, `gws-align-managers`, `gws-build-all-group` | Go | ad-hoc | any |
| `frigg-linux` | formula | [frigg](https://github.com/21StarkCom/frigg) | `frigg`, `frigg-cockpit`, `gws-align-managers`, `gws-build-all-group` | Go | none | none: Linux x86_64 |
| `heimdall` | formula | [heimdall](https://github.com/21StarkCom/heimdall) | `heimdall` | Go | Developer ID + notarized | any |
| `hermod` | formula | [hermod](https://github.com/21StarkCom/hermod) | `hermod` | `bun build --compile` | ad-hoc | 27 (Golden Gate) |
| `hermod-linux` | formula | [hermod](https://github.com/21StarkCom/hermod) | `hermod` | `bun build --compile` | none | none: Linux x86_64 |
| `idun` | formula | [idun](https://github.com/21StarkCom/idun) | `idun` | `bun build --compile` | Developer ID + notarized | 27 (Golden Gate) |
| `lucius` | formula | [lucius](https://github.com/21StarkCom/lucius) | `lucius` | Bun source tree | none of its own; its one Mach-O is Anthropic-signed | any |
| `lumiere` | formula | [lumiere](https://github.com/21StarkCom/lumiere) | `lumiere`, `lumiere-*` | Go | Developer ID + notarized | 26 (Tahoe) |
| `plume` | formula | [plume](https://github.com/21StarkCom/plume) | `plume-*` | Go | ad-hoc | any |
| `sleipnir` | formula | [sleipnir](https://github.com/21StarkCom/sleipnir) | `slp`, `sleipnir`, `huginn`, `sleipnir-mcp` | Bun source tree | Developer ID + notarized `mac-helper` | any |
| `stark-statusline` | formula | [idavoll](https://github.com/21StarkCom/idavoll) | `stark-statusline` | Go | ad-hoc | 13 (Ventura) |
| `tyr` | formula | [tyr](https://github.com/21StarkCom/tyr) | `tyr` (frozen at v0.109.0) | Go | Developer ID + notarized | any |
| `atlas` (cask) | cask | [atlas](https://github.com/21StarkCom/atlas) | `Atlas.app` | Electron app | Developer ID + notarized + stapled | 13 (Ventura); its bundled Node needs 13.5 |
| `goldfinger` (cask) | cask | [goldfinger](https://github.com/21StarkCom/goldfinger) | `Goldfinger.app` (nesting Goldfinger Control, the menu bar helper, from 0.8.0), `goldfinger` | Swift app | Developer ID + notarized + stapled | 26 (Tahoe) |
| `mimir` (cask) | cask | [mimir](https://github.com/21StarkCom/mimir) | `Mimir.app`, `mimir` | Swift app | Developer ID + notarized + stapled | 26 (Tahoe) |

"any" means the entry declares no macOS floor beyond Apple Silicon.

## alfred

The [`alfred`](https://github.com/21StarkCom/alfred) ops butler: the `alfred` ticket and
ops CLI, plus `alfredd`, its always-on local daemon.

```sh
brew install 21StarkCom/tap/alfred
alfredd install      # once: write the daemon's LaunchAgent plist and load it
```

The plist pins Homebrew's stable `opt` path, so an upgrade never orphans the daemon. Both
binaries are Developer-ID signed + notarized Go builds.

## bragi

The [`bragi`](https://github.com/21StarkCom/bragi) streaming-voice toolkit: speech-to-text
and text-to-speech as streams, driven by a JSON-lines session protocol, for agents that
listen and speak. `bragi` is the Go CLI, and `bragi-audio` the Swift helper that owns the
microphone and the speaker.

```sh
brew install 21StarkCom/tap/bragi
bragi doctor         # the helper, the microphone, the providers' credentials
```

**macOS 15 (Sequoia) or newer.** Both binaries are Developer-ID signed + notarized, and
`bragi-audio` carries the microphone entitlement. bragi starts the helper from beside its
own resolved path, so the formula installs the two side by side. The first capture asks
macOS for the microphone in your terminal's name.

## brain

The [`brain`](https://github.com/21StarkCom/atlas) CLI — the **Atlas** engine
(`@atlas/cli`): ingest notes, build the retrieval index, query/answer over a
vault, and run the review/housekeep surfaces.

```sh
brew install 21StarkCom/tap/brain
```

Unlike the single-binary CLIs, `brain` is **node ESM** inside a pnpm monorepo, so the
release zip is a **`pnpm deploy` tree** — `dist/`, a vendored `node_modules` (workspace
`@atlas/*` deps plus the two used native modules, `better-sqlite3` and
`@lancedb/lancedb-darwin-arm64`; LanceDB's optional ML embedding stack is pruned), and the
runtime command registry at `docs/specs/cli-contract/`. The formula installs that tree into
`libexec`, wraps `brain` to run under the keg's `node`, and pins `ATLAS_ROOT` so the
registry always resolves. The natives are **Developer-ID signed + notarized** (submission
recorded in the `21StarkCom/apple-developer` ledger). A CLI zip can't be offline-**stapled**,
so it's online-notarized — moot under Homebrew, which installs a formula's files without the
quarantine xattr.
Released from `cli-v*` tags, parallel to the desktop app's `desktop-v*`.

## frigg

The [`frigg`](https://github.com/21StarkCom/frigg) IT-ops toolkit for Google Workspace and
the vendor fleet: the `frigg` CLI, the `frigg-cockpit` TUI, and two single-purpose
Workspace CLIs, `gws-align-managers` (bulk-align org-chart manager edges from a CSV) and
`gws-build-all-group` (rebuild the all-hands group from the directory). Both `gws-*` tools
dry-run by default; `--apply` mutates the live directory.

```sh
brew install 21StarkCom/tap/frigg
```

The binaries carry Go's linker **ad-hoc** signature, not a Developer ID.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/frigg-linux
```

`frigg-linux` installs the same four tools from the static linux/amd64 build that frigg's
release ships beside the darwin one. It is a formula of its own for the reason
`hermod-linux` is (see [hermod](#hermod)), and its binaries are unsigned. On another
platform, `go install` from the `frigg` repo.

## heimdall

The [`heimdall`](https://github.com/21StarkCom/heimdall) CLI — personal
native-APNs push relay. `heimdall send <title>` fires a Mac banner **and** pushes
to your iPhone / iPad via your own APNs key and app (no third-party push service).

```sh
brew install 21StarkCom/tap/heimdall
```

The zip is the Developer-ID-signed + notarized `heimdall` binary. Config (backend URL +
send-secret) reads from the login Keychain (service `heimdall`), or `HEIMDALL_URL` /
`HEIMDALL_SEND_SECRET`.

## hermod

The [`hermod`](https://github.com/21StarkCom/hermod) CLI + engine for
the [cmux](https://github.com/manaflow-ai/cmux) control API — one bun/TypeScript
binary that spawns/splits tabs, drives the per-workspace todo checklist (a one-shot
command group plus an interactive TUI), finds orphaned surface processes, and discovers
and messages peer agent sessions (`msg`).

```sh
brew install 21StarkCom/tap/hermod
```

The release zip is a `bun build --compile` binary carrying bun's linker-signed **ad-hoc**
signature, not a Developer ID. It is compiled with the release Mac's Homebrew `bun`, whose
build targets macOS 27.0, so the formula requires macOS 27 (Golden Gate). `hermod` reaches its
cmux app over the inherited `CMUX_SOCKET_PATH`, so run it from inside a cmux surface (or
set the socket env yourself).

On Linux x86_64 (the devbox), where hermod drives tmux instead:

```sh
brew install 21StarkCom/tap/hermod-linux
```

`hermod-linux` installs the same `hermod`, cross-compiled by the release Mac with
`bun build --compile --target=bun-linux-x64`. It is a formula of its own because a
formula cannot pin a url inside `on_macos`/`on_linux` blocks (`brew style` refuses it),
as hermod's ADR 0013 records. The binary is unsigned; Linux has no Gatekeeper.

## idun

The [`idun`](https://github.com/21StarkCom/idun) personal-ops maintenance CLI —
one bun/TypeScript binary, one subcommand per tool (GitHub identity swap, seat
rotation, cleanup, housekeeping, updates).

```sh
brew install 21StarkCom/tap/idun
```

The release zip is a `bun build --compile` binary, Developer-ID signed + notarized. It is
compiled with the release Mac's Homebrew `bun`, whose build targets macOS 27.0, so the
formula requires macOS 27 (Golden Gate). A checkout of the `idun` repo can instead
install a live, repo-tracking wrapper with `./setup.sh`, which steps aside when this
formula is installed.

## lucius

The [`lucius`](https://github.com/21StarkCom/lucius) CLI — a terminal brainstorming
partner on the Claude Agent SDK by default, with a selectable OpenAI backend, that
recalls from `brain` and keeps its own vault.

```sh
brew install 21StarkCom/tap/lucius
```

Same shape as `sleipnir`: Bun runs the TypeScript directly, so the release zip is the
runnable tree (`bin/`, `src/`, `package.json`, `bun.lock`) plus a vendored prod
`node_modules`. The formula installs it into `libexec` and wraps `lucius` over Homebrew's
`bun` (a formula dependency), which must be **1.4.2 or newer** — lucius refuses to start on
an older one, so `brew upgrade bun` if you are behind. Homebrew cannot express that floor
on a formula dependency, so `brew install` succeeds and the refusal only shows on the first
run. The tree's one Mach-O is the Agent SDK's own `claude` binary, signed by Anthropic;
`src/vault/publication.c` ships beside its loader because `bun:ffi` compiles it at runtime.

The wrapper runs `bun --no-env-file --config=/dev/null`, so the caller's working
directory can't inject a `.env` or a `bunfig.toml` preload into lucius.

## lumiere

The [`lumiere`](https://github.com/21StarkCom/lumiere) visual-media CLI toolkit —
the `lumiere-*` tools (image gen/edit, SVG suite, video, brand icons, …), fronted
by a `lumiere` dispatcher (`lumiere <tool> [args]`, `lumiere --help` for the list).

```sh
brew install 21StarkCom/tap/lumiere
```

**macOS 26 (Tahoe) or newer.** The ONNX tools (`lumiere-bg`, `lumiere-bg-swap`,
`lumiere-product`, `lumiere-upscale`, `lumiere-veo`) are built for macOS 26.0. The release
zip is a Developer-ID-signed + notarized `darwin_arm64` build. Linux users build from source
in the `lumiere` repo (`make build`).

## plume

The [`plume`](https://github.com/21StarkCom/plume) pure-Go document toolkit — one
`plume-<format>` driver per format (`plume-xlsx`, `plume-docx`, `plume-pdf`,
`plume-pptx`, `plume-handwriting`), each a thin CLI over the format's library
package (the library is the product; these binaries are the drivers).

```sh
brew install 21StarkCom/tap/plume
```

plume is `CGO_ENABLED=0` pure Go and its `release.yml` genuinely cross-compiles
`{linux,darwin}/{amd64,arm64}`, so a non-Mac (or Intel Mac) can `make build` /
`go install` straight from the `plume` repo; the formula pins the darwin/arm64
tarball only. That build carries Go's linker **ad-hoc** signature, not a Developer ID.

## sleipnir

The [`sleipnir`](https://github.com/21StarkCom/sleipnir) CLI — drives dedicated,
persistent Chrome profiles for ad-hoc agent tasks (per-task user-agent, headless
or headed, plus a suite of capabilities).

```sh
brew install 21StarkCom/tap/sleipnir
```

sleipnir drives system Chrome and a Swift AX/CGEvent helper, so there is no Linux build.
sleipnir has **no build step** — Bun runs its TypeScript directly — so the release zip is
the runnable tree (source + a vendored prod `node_modules`) plus the Developer-ID-signed +
notarized Swift `mac-helper`. The formula installs the tree into `libexec` and wraps `slp` /
`sleipnir`, `huginn` (the Sleipnir Huginn browser extension's CLI, from 0.11.0) and
`sleipnir-mcp` (the MCP server an agent client runs, from 0.12.1) over Homebrew's
`bun` (a formula dependency), each keeping the caller's working-directory `.env` and
`bunfig.toml` out. Name it in full —
`brew upgrade 21StarkCom/tap/sleipnir` — since a bare `sleipnir` is homebrew/cask's
browser of the same name.

## stark-statusline

The Claude Code statusline from [`idavoll`](https://github.com/21StarkCom/idavoll):
`stark-statusline render` is the `statusLine` command, reading Claude Code's JSON on stdin,
and the bare command opens a terminal editor that turns segments on and off and moves them
between the three lines. `stark-statusline install` points `~/.claude/settings.json` at it
by absolute path (the `stark-statusline` first on `PATH`, `/opt/homebrew/bin`'s link under
Homebrew), since Claude Code may run the command without Homebrew's bin on `PATH`. It
replaces any `statusLine` command already there and keeps the file's other keys. Run it
again over the bare `stark-statusline render` that 0.1.0's `install` wrote.

```sh
brew install 21StarkCom/tap/stark-statusline
stark-statusline install
```

The binary carries Go's linker **ad-hoc** signature, not a Developer ID. It runs on macOS
only. On an Intel Mac, run `go install ./statusline/cmd/stark-statusline` in an `idavoll` checkout,
with Go's bin directory on `PATH`: `install` wires that binary by its absolute path.

## tyr

```sh
brew install 21StarkCom/tap/tyr
```

A frozen CLI: [`tyr`](https://github.com/21StarkCom/tyr) is now a library-only Go module,
the vendor-integration capabilities that `frigg` drives, and it ships no binary. No release
bumps this formula, so it stays on the last CLI build, v0.109.0, Developer-ID signed +
notarized. For the live capabilities, use `frigg`.

## atlas (desktop app — cask)

The **Atlas** desktop app — the GUI companion to the `brain` CLI (same
`21StarkCom/atlas` repo). A GUI `.app`, so it ships as a **cask**:

```sh
brew install --cask 21StarkCom/tap/atlas
```

`Atlas.app` lands in `/Applications`. The bundle carries its own internal CLI
closure (a standalone Node + `brain` bin it spawns for status checks), so — unlike
`mimir` — the cask exposes **no `binary`**: `brain` is its own formula and must not
be shadowed. **macOS 13.5+ arm64:** the cask's floor is Ventura, but the bundled
Node needs 13.5, so on 13.0–13.4 the app starts and its CLI does not. The build
is Developer-ID **signed + notarized** (`spctl` reports "Notarized Developer ID")
and **stapled**: every install or upgrade lands it quarantined, and Gatekeeper
validates its stapled ticket offline at the first launch after each.
Released from the source repo's `desktop-v*` tags (parallel to the CLI's `cli-v*`).

## goldfinger (background computer use — cask)

[`goldfinger`](https://github.com/21StarkCom/goldfinger) — background computer use for
agents: `Goldfinger.app` runs the daemon that holds the macOS grants, and the `goldfinger`
CLI observes and operates native apps without taking the user's focus. The daemon is a GUI
app, so it ships as a **cask** (`Casks/goldfinger.rb`):

```sh
brew install --cask 21StarkCom/tap/goldfinger
goldfinger setup      # once: grant Accessibility and Screen Recording
```

The cask drops `Goldfinger.app` into `/Applications` and symlinks its executable, which is
both the daemon and the CLI, onto your `PATH` as `goldfinger`. **macOS 26 (Tahoe) or
newer.** The release zip is the Developer-ID-signed, notarized and **stapled**
`Goldfinger.app`. Homebrew installs it quarantined, so macOS may first ask whether to open
Goldfinger: allow it, and re-run `goldfinger setup` if it gave up waiting for the daemon.

**Goldfinger Control** is the menu bar helper nested in the app at
`Contents/Library/LoginItems/Goldfinger Control.app` (`com.21stark.goldfinger.control`): it
shows the daemon's state and starts, stops or restarts it. It ships from 0.8.0 on; 0.7.0 and
older have none. Nothing starts it at install: run `goldfinger doctor --fix` once after
installing, which registers it as a login item (Open at Login) and launches it; once you turn
Open at Login off, it stays off. If its icon is hidden (a crowded or notched menu bar, or
System Settings → Menu Bar), open its panel with `env -i /usr/bin/open -g '/Applications/Goldfinger.app/Contents/Library/LoginItems/Goldfinger Control.app'`.

`brew upgrade` quits the running daemon and Goldfinger Control (`uninstall quit:` names both
ids), then reopens each one it quit by bundle id; the app serves as the new daemon. Homebrew
upgrades by the installed caskfile, so an upgrade from a release without Goldfinger Control
quits only the daemon, and nothing registers or starts the helper: run
`goldfinger doctor --fix` once after that upgrade. On a Mac that also holds dev builds (the
daemon's bundle id; dev helpers carry `com.21stark.goldfinger.control.dev`), LaunchServices
may reopen a dev daemon instead: run `goldfinger stop`, and the next `goldfinger` command
starts the installed one. After `brew upgrade`, restart any agent running `goldfinger mcp`:
until it restarts, the new daemon answers its calls with `version_mismatch`.

`brew uninstall --cask goldfinger` quits both apps and removes the app and its link, but leaves
Goldfinger Control's login item registered (System Settings → General → Login Items &
Extensions). `--zap` also deletes that login item by name through System Events, so macOS asks
your terminal for Automation access (`login_item:`; the helper's `SMAppService.mainApp`
registration owns no launchd job, so there is no `launchctl:`), and trashes
`~/Library/Caches/goldfinger` (socket, lock, screenshots),
`~/Library/Caches/com.21stark.goldfinger` (from 0.9.0 on, the model cache macOS compiles for
Vision text recognition and Core ML icon detection, which dev daemons share),
`~/Library/Application Support/goldfinger` (the snapshot epoch and every recording: the
trajectories and videos under `recordings/`) and the helper's
`~/Library/Preferences/com.21stark.goldfinger.control.plist`. Neither revokes the grants:
remove Goldfinger in System Settings → Privacy & Security, or run
`tccutil reset Accessibility com.21stark.goldfinger` and
`tccutil reset ScreenCapture com.21stark.goldfinger`.

## mimir (credential vault — cask)

[`mimir`](https://github.com/21StarkCom/mimir) — a personal macOS credential vault
with a paired `mimir` CLI and a loopback MCP server for agents. It is a **GUI app**, so it
ships as a **cask** (`Casks/mimir.rb`):

```sh
brew install --cask 21StarkCom/tap/mimir
```

The cask drops `Mimir.app` into `/Applications` and symlinks the bundled `mimir` CLI onto
your `PATH`. **macOS 26 (Tahoe) or newer.** The release zip is the Developer-ID-signed,
notarized, and **stapled** `Mimir.app`, so Gatekeeper validates it offline. The app registers
**Mímir Service**, the launchd agent the CLI and MCP talk to, only from `/Applications` or
`~/Applications`, so keep the cask's `--appdir` at one of those. `brew upgrade` quits the app and
its menu bar item (`uninstall quit:`) and reopens both by bundle id. On a Mac that also holds dev
builds (same bundle ids), LaunchServices may reopen one of those instead: quit both and open the
installed Mímir, whose launch opens its own menu by path. The service restarts itself on the new
bundle, so the cask never boots it out on upgrade. `brew uninstall --cask mimir` removes the app
but leaves the service and the menu's login item registered with launchd;
`brew uninstall --zap --cask 21StarkCom/tap/mimir` also removes both (`zap launchctl:`) and
trashes its local data (but never the login-Keychain vault key — that is the app's own Danger
Zone → Erase Everything). Once a plain uninstall has run, add `--force`, and keep the full name:
that uninstall drops Homebrew's trust in the cask, and an untrusted tap's cask loads only when
named in full.

## Repo layout

| Path | What it holds |
|---|---|
| `Formula/` | One Ruby formula per CLI, plus `hermod-linux` and `frigg-linux`, their tools' Linux builds. |
| `Casks/` | One cask per GUI app, each with an initialization-only download adapter. |
| `scripts/bump.sh` | The bumper: re-pins one entry to a published release and opens the PR. `--help` is its reference. |
| `scripts/test-bump.sh` | The bumper's tests, against a bare remote and a stubbed `gh`. |
| `scripts/verify-auth.rb` | Checks the missing and whitespace-only token errors, with synthetic credentials only and gh's login hidden. |
| `scripts/verify-download.rb` | Checks hermod's authenticated preflight and a partial-download resume against the pinned checksum. |
| `.github/workflows/formulae.yml` | On ubuntu arm64 (Homebrew on Linux): styles every entry, runs both verify scripts, audits and fetches every formula and cask, and fetches with only a gh login. |
| `.github/workflows/bump.yml` | Runs `scripts/test-bump.sh` on ubuntu, and under bash 3.2 in the `bash:3.2` image. |
| `.github/workflows/secret-scan.yml` | The fleet's shared secret scan. |

## How it fits the fleet

The tap is a passive publish target. Each source repo's release re-pins its own entry by
running this repo's `scripts/bump.sh` (21stark ADR-0008), which reads the asset id and
checksum back from the published release and opens a PR here. Two entries have no release
that bumps them: the atlas cask, re-pointed by hand at a `desktop-v*` release, and tyr, a
frozen v0.109.0 CLI from before tyr became library-only.

On a bare Mac, [idavoll](https://github.com/21StarkCom/idavoll)'s installer reads `Formula/`
and `Casks/` from its clone of this repo and installs every entry, so a new entry reaches the
next rebuilt machine with no change to the installer. It leaves out every formula that
declares `depends_on :linux` (`hermod-linux`, `frigg-linux`). idavoll's devbox profile
works the other way: it installs, builds or skips each entry as idavoll's
`config/linux-clis.json` says, and reports a failure for an entry that file does not
list, so a new entry needs its line there too (STARK-11780 places `frigg-linux`).

## Releases: who bumps each entry

Each entry pins three release-specific lines: `version`, the release asset's id in its
`url`, and `sha256`. Do **not** hand-edit them. The source repo's release step calls the
bumper, which reads them back from the published GitHub Release and opens a PR here.
`scripts/bump.sh --help` is the bumper's reference, and CLAUDE.md says how to run it by hand.

| Entry | Source repo | Release step that calls the bumper | Runs on |
|---|---|---|---|
| `alfred` | alfred | `scripts/release-darwin.sh` | the signing Mac |
| `bragi` | bragi | `scripts/release-darwin.sh` | the signing Mac |
| `brain` | atlas | `scripts/release-darwin.sh`, for a `cli-v*` tag | the signing Mac |
| `frigg` | frigg | `.github/workflows/release.yml` | GitHub Actions |
| `frigg-linux` | frigg | `.github/workflows/release.yml` `publish` (`--asset-suffix linux_amd64.zip`) | GitHub Actions |
| `heimdall` | heimdall | `scripts/release-darwin.sh` | the signing Mac |
| `hermod` | hermod | `ts/scripts/release-darwin.sh` | the signing Mac |
| `hermod-linux` | hermod | `ts/scripts/release-darwin.sh` (`--asset-suffix linux_x64.zip`) | the signing Mac |
| `idun` | idun | `scripts/release-darwin.sh` | the signing Mac |
| `lucius` | lucius | `scripts/release-darwin.sh` | the signing Mac |
| `lumiere` | lumiere | `scripts/release-darwin.sh` | the signing Mac |
| `plume` | plume | `.github/workflows/release.yml` | GitHub Actions |
| `sleipnir` | sleipnir | `scripts/release-darwin.sh` | the signing Mac |
| `stark-statusline` | idavoll | `statusline/release.sh` (`make statusline-release STATUSLINE_VERSION=X.Y.Z`), for a `statusline-v*` tag | the operator's Mac |
| `tyr` | tyr | none: tyr is library-only and ships no binary, so the formula stays on its last CLI release | — |
| `atlas` (cask) | atlas | none: no release step bumps it, so re-point it by hand at a `desktop-v*` release (`--asset-suffix .zip`) | — |
| `goldfinger` (cask) | goldfinger | `macos/scripts/release-darwin.sh` | the signing Mac |
| `mimir` (cask) | mimir | `scripts/release-darwin.sh` | the signing Mac |

idun's and alfred's releases and plume's and frigg's `release.yml` merge their own bump PRs
unattended (frigg's two: `frigg` and `frigg-linux`): `bump.sh --merge` waits for every
check here first. frigg's run leaves its PRs open, under a warning, while its token lacks
Actions: read on this tap. Every other bump PR stays open for a hand merge with
`idun gh pr-merge`, titled `chore(STARK-<n>): …` when a ticket covers it and labeled
`no-ticket` (by `bump.sh`) while its title names no ticket.

## Download authentication and CI

All entries use native download auth headers, including preflight metadata requests. Formulae declare URL `headers:` directly. Casks use initialization-only adapters so tokens are never serialized in cask JSON; all network operations remain Homebrew's. Homebrew handles redirects, cache freshness, and partial resume. Each entry takes its token from Homebrew's own lookup (`HOMEBREW_GITHUB_API_TOKEN`, else Homebrew's gh login, else a keychain token), stripped before use; a whitespace-only env var counts as unset, and when the lookup finds nothing the entry reports the asset URL and setup guidance. Homebrew redacts only environment secrets from its output, so with a gh-only login, `--verbose --debug` or `HOMEBREW_CURL_VERBOSE` output shows the gh token: don't paste it anywhere. Formula validation happens during evaluation, so formula metadata commands require the token too. Casks validate when their downloader is initialized.

Pull requests run on ubuntu arm64, under Homebrew on Linux: `brew style`, missing-token checks, and `brew audit --strict` and `brew fetch` for every formula, which checks its download against the pinned `sha256`; each `<tool>-linux` formula (`hermod-linux`, `frigg-linux`) is audited as Linux x86_64, and CI requires its fetch to have downloaded a Linux x86-64 `<tool>`. Every cask is fetched with the token, which checks its download against the pinned `sha256`, and strict-audited with `brew audit --cask --strict`, skipping only `sha256_no_check_if_unversioned` (plus `token_conflicts` for atlas). A separate hermod download check verifies authenticated metadata and partial resume against the release checksum. Every entry but the two `-linux` formulae is macOS-only, and those are x86_64-only on the arm runner, so CI installs and tests none of them; `brew reinstall` and `brew test` do, on a Mac, and on the x86_64 devbox for the `-linux` formulae. The `bump` workflow runs the bumper's tests (`scripts/test-bump.sh`) on ubuntu, and under bash 3.2 in the `bash:3.2` image. CI uses the repository Actions secret `HOMEBREW_RELEASE_READ_TOKEN`, with read access to the private release repositories.
