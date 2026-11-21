# homebrew-tap

Public [Homebrew](https://brew.sh) tap for the 21Stark fleet, referenced by brew as
`21StarkCom/tap`. It puts the fleet's tools on an Apple Silicon Mac with one
`brew install`: 22 formulae for the CLIs and 4 casks for the GUI apps, each a signed
macOS arm64 build (muninn: an unsigned bash tree) pulled from a GitHub Release, plus eight `-linux` formulae,
the Linux x86_64 builds for the devbox of muxctl, frigg, urd, sonar, ghx, utgard and idun's two apps
(`idun-linux` and `valkyrie-linux`). Every entry is [public](#public-entries): it downloads from a
release of this tap with no GitHub login. The source repos stay private. The tap builds nothing. It only pins
each entry to a published release, and each source repo's release re-pins its own entry by pull request.

**Status:** active. Every entry installs today; 32 of the 34 are re-pinned on each release
of their source repo, and the other two are named under
[How it fits the fleet](#how-it-fits-the-fleet). Contributors: the rules for editing an
entry, running the bumper and verifying a change are in [CLAUDE.md](CLAUDE.md).

## In the saga

Pens and pictures reach the operator's hands through [homebrew-tap](https://github.com/21StarkCom/homebrew-tap), the house's public Homebrew tap and home of the one bumper script that source repos' releases run to re-pin their entries by pull request. It appears in [plume](https://github.com/21StarkCom/plume)'s chapter of [The Saga of House Stark](https://github.com/21StarkCom/.github/blob/main/fleet/saga.md).

---

## Install

```sh
# Once. The tap repo is public: brew clones it over HTTPS with no key or token.
brew tap 21StarkCom/tap
# Every entry installs with no GitHub login.
brew install 21StarkCom/tap/<formula>
brew install --cask 21StarkCom/tap/<cask>
brew upgrade 21StarkCom/tap/<name>
```

No entry holds token code. A formula's files are installed without the
quarantine xattr, so an ad-hoc-signed or un-notarized build runs under Homebrew but hits
Gatekeeper if you unzip the release by hand. Casks install their apps quarantined. Every entry but
the eight `-linux` formulae is **macOS arm64 only**; for another platform,
build from the tool's own repo where it supports one (the agent-seats, frigg, lumiere, plume,
sonar, stark-statusline and urd sections say how).

A tap first added over SSH (`git@github.com:21StarkCom/homebrew-tap.git`) keeps that remote
and works as before.

## Entries

| Entry | Kind | Source repo | Installs | Build | Signing | macOS |
|---|---|---|---|---|---|---|
| `agent-seats` | formula | [agent-seats](https://github.com/21StarkCom/agent-seats) | `agent-seats`, `seat-login`, the Seat login extension | `bun build --compile`, Vite | Developer ID (team `MG9J2XF9Q3`), not notarized | 27 (Golden Gate) |
| `alfred` | formula | [odin](https://github.com/21StarkCom/odin) | `alfred`, `alfredd` | Go | Developer ID + notarized | any |
| `bragi` | formula | [bragi](https://github.com/21StarkCom/bragi) | `bragi`, `bragi-audio` | Go + a Swift helper | Developer ID + notarized | 15 (Sequoia) |
| `brain` | formula | [atlas](https://github.com/21StarkCom/atlas) | `brain` (and a `brew services` job) | node ESM tree | Developer ID + notarized native modules in the zip; lancedb ad hoc once installed | any |
| `floorplan` | formula | [floorplan](https://github.com/21StarkCom/floorplan) | `floorplan` | node ESM tree | none of its own; its native npm prebuilds are ad-hoc (the linker's signature; the three it renames, re-signed ad hoc in the keg) | any |
| `frigg` | formula | [frigg](https://github.com/21StarkCom/frigg) | `frigg`, `frigg-*`, `frg-*`, `gws-*` | Go | ad-hoc | any |
| `frigg-linux` | formula | [frigg](https://github.com/21StarkCom/frigg) | `frigg`, `frigg-*`, `frg-*`, `gws-*` | Go | none | none: Linux x86_64 |
| `ghx` | formula | [github-extended](https://github.com/21StarkCom/github-extended) | `ghx` | `bun build --compile` | Developer ID + notarized | 27 (Golden Gate) |
| `ghx-linux` | formula | [github-extended](https://github.com/21StarkCom/github-extended) | `ghx` | `bun build --compile` | none | none: Linux x86_64 |
| `heimdall` | formula | [heimdall](https://github.com/21StarkCom/heimdall) | `heimdall` | Go | Developer ID + notarized | any |
| `idun` | formula | [idun](https://github.com/21StarkCom/idun) | `idun` | `bun build --compile` | Developer ID + notarized | 27 (Golden Gate) |
| `idun-linux` | formula | [idun](https://github.com/21StarkCom/idun) | `idun` | `bun build --compile` | none | none: Linux x86_64 |
| `librarian` | formula | [atlas](https://github.com/21StarkCom/atlas) | `librarian` (and a `brew services` daemon) | node ESM tree | none of its own; its one Mach-O is Anthropic-signed | any |
| `lumiere` | formula | [lumiere](https://github.com/21StarkCom/lumiere) | `lumiere`, `lumiere-*` | Go | Developer ID + notarized | 26 (Tahoe) |
| `muninn` | formula | [muninn](https://github.com/21StarkCom/muninn) | `muninn-install` | bash source tree | none (no Mach-O) | any |
| `muxctl` | formula | [mux-control](https://github.com/21StarkCom/mux-control) | `muxctl`, `hermod` (a link to `muxctl`) | `bun build --compile` | ad-hoc | 27 (Golden Gate) |
| `muxctl-linux` | formula | [mux-control](https://github.com/21StarkCom/mux-control) | `muxctl`, `hermod` (a link to `muxctl`) | `bun build --compile` | none | none: Linux x86_64 |
| `odinctl` | formula | [odin](https://github.com/21StarkCom/odin) | `odinctl`, `odin` | node ESM tree | Developer ID + notarized `odin-face` and `desk`; its `claude` is Anthropic-signed | any |
| `plume` | formula | [plume](https://github.com/21StarkCom/plume) | `plume`, `plume-*` | Go | ad-hoc | any |
| `sleipnir` | formula | [sleipnir](https://github.com/21StarkCom/sleipnir) | `slp`, `sleipnir`, `huginn`, `sleipnir-mcp` | minified Bun bundles | Developer ID + notarized native modules in the zip; ad hoc once installed | any |
| `sonar` | formula | [sonar](https://github.com/21StarkCom/sonar) | `sonar` | Go | ad-hoc | any |
| `sonar-linux` | formula | [sonar](https://github.com/21StarkCom/sonar) | `sonar` | Go | none | none: Linux x86_64 |
| `stark-statusline` | formula | [idavoll](https://github.com/21StarkCom/idavoll) | `stark-statusline` | Go | ad-hoc | 13 (Ventura) |
| `tyr` | formula | [tyr](https://github.com/21StarkCom/tyr) | `tyr` (frozen at v0.109.0) | Go | Developer ID + notarized | any |
| `urd` | formula | [urd](https://github.com/21StarkCom/urd) | `urd` | Go | ad-hoc | any |
| `urd-linux` | formula | [urd](https://github.com/21StarkCom/urd) | `urd` | Go | none | none: Linux x86_64 |
| `utgard` | formula | [utgard](https://github.com/21StarkCom/utgard) | `utgard` | `bun build --compile` | Developer ID + notarized | 27 (Golden Gate) |
| `utgard-linux` | formula | [utgard](https://github.com/21StarkCom/utgard) | `utgard` | `bun build --compile` | none | none: Linux x86_64 |
| `valkyrie` | formula | [idun](https://github.com/21StarkCom/idun) | `valkyrie` | `bun build --compile` | Developer ID + notarized | 27 (Golden Gate) |
| `valkyrie-linux` | formula | [idun](https://github.com/21StarkCom/idun) | `valkyrie` | `bun build --compile` | none | none: Linux x86_64 |
| `atlas` (cask) | cask | [atlas](https://github.com/21StarkCom/atlas) | `Atlas.app` | Electron app | Developer ID + notarized + stapled | 13 (Ventura); its bundled Node needs 13.5 |
| `goldfinger` (cask) | cask | [goldfinger](https://github.com/21StarkCom/goldfinger) | `Goldfinger.app` (nesting Goldfinger Control, the menu bar helper, from 0.8.0), `goldfinger` | Swift app | Developer ID + notarized + stapled | 26 (Tahoe) |
| `idavoll` (cask) | cask | [idavoll](https://github.com/21StarkCom/idavoll) | `Idavoll.app`, `/usr/local/bin/idavoll`, from the release's `.pkg` | Go CLI in an Electron app | Developer ID + notarized + stapled `.pkg` | 13 (Ventura) |
| `mimir` (cask) | cask | [mimir](https://github.com/21StarkCom/mimir) | `Mimir.app`, `mimir` | Swift app | Developer ID + notarized + stapled | 26 (Tahoe) |

"any" means the entry declares no macOS floor beyond Apple Silicon. In the Signing column,
"ad-hoc" is the linker's own signature, new on each build. "Ad hoc once installed" means that
Homebrew re-signs a dylib ad hoc in the keg when it rewrites the dylib's install name.

## agent-seats

The [`agent-seats`](https://github.com/21StarkCom/agent-seats) seat manager: several
Claude Code and Codex logins on one Mac, the daemon that rotates them by live usage, and
`seat-login`, the CLI that drives the Seat login browser extension.

```sh
brew install 21StarkCom/tap/agent-seats
agent-seats daemon install    # once: register the daemon on the brew binary's link
agent-seats daemon restart    # after each upgrade: the running daemon is the old binary
```

The release zip holds two `bun build --compile` binaries, Developer-ID signed (team
`MG9J2XF9Q3`) but **not notarized**: Homebrew installs a formula's files without the
quarantine xattr, so Gatekeeper never checks them. The Developer ID keeps the daemon's
Keychain grants for its Codex logins across upgrades, which an ad-hoc signature, new on
every build, would not. They are compiled with the release Mac's Homebrew `bun`, whose
build targets macOS 27.0, so the formula requires macOS 27 (Golden Gate). On Linux
x86_64, install `agent-seats` from the release's `linux_x64` tarball or build it from
source, as the `agent-seats` repo's `apps/agent-seats/README.md` says.

The zip also holds the Seat login Chrome extension, unpacked and minified, as
`seat-login-extension/`. The formula installs it in `libexec`, which brew does not link into
the prefix, and its `post_install_steps` copy it to `$(brew --prefix)/var/seat-login/extension`
on each install and upgrade. Chrome keeps an unpacked extension's real path, so a folder in
the keg would break when `brew cleanup` deletes the old version. Load that folder once in
`chrome://extensions` (Developer mode, **Load unpacked**), and click Reload on its card
after each upgrade. For the `seat-login` CLI and Codex sign-in, run `seat-login install`
once, then reload the extension. A packed `.crx` is not possible: Chrome on a Mac with no
MDM installs one only from the Chrome Web Store.

## alfred

The [`alfred`](https://github.com/21StarkCom/odin) ops butler: the `alfred` ticket and
ops CLI, plus `alfredd`, its always-on local daemon. Released from `alfred-v*` tags by
odin's `packages/toolbox/scripts/release-darwin.sh` since 0.62.0; earlier releases came
from the `alfred` repo.

```sh
brew install 21StarkCom/tap/alfred
alfredd install      # once: write the daemon's LaunchAgent plist and load it
```

The plist pins Homebrew's stable `opt` path, so an upgrade never orphans the daemon. Both
binaries are Developer-ID signed + notarized Go builds. The formula depends on this tap's
[`urd`](#urd) formula, by its full name, because alfred reads the cache through `urd`.

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
`bragi-audio` carries the microphone entitlement and its own usage string. bragi starts the
helper from beside its own resolved path, so the formula installs the two side by side. The
first `bragi listen` or `bragi session` asks macOS for the microphone as bragi-audio, whoever
started bragi. macOS keys that answer to the helper's keg path, so each `brew upgrade bragi`
asks once more. `bragi doctor` never asks: until macOS has asked, it warns
`audio.permission_pending`.

## brain

The [`brain`](https://github.com/21StarkCom/atlas) CLI — the **Atlas** engine
(`@atlas/cli`): ingest notes, build the retrieval index, query/answer over a
vault, and run the review/housekeep surfaces.

```sh
brew install 21StarkCom/tap/brain
brew services start brain    # runs `brain vaults sync --pull` every 10 minutes
```

Unlike the single-binary CLIs, `brain` is **node ESM** inside a pnpm monorepo, so the
release zip is a **`pnpm deploy` tree** — `dist/`, a vendored `node_modules` (workspace
`@atlas/*` deps plus the two used native modules, `better-sqlite3` and
`@lancedb/lancedb-darwin-arm64`; LanceDB's optional ML embedding stack is pruned), and the
runtime command registry at `docs/specs/cli-contract/`. The formula installs that tree into
`libexec`, wraps `brain` to run under the keg's `node`, and pins `ATLAS_ROOT` so the
registry always resolves. The natives are **Developer-ID signed + notarized** in the release
zip (submission recorded in the `21StarkCom/apple-developer` ledger). The lancedb module in
the keg carries an ad hoc signature: it is a dylib, so on install Homebrew rewrites its
install name to the `opt` path and re-signs it ad hoc. `better-sqlite3` is a bundle, which
has no install name, so it keeps its Developer ID signature. A CLI zip can't be
offline-**stapled**, so it's online-notarized — moot under Homebrew, which installs a
formula's files without the quarantine xattr.
Released from `cli-v*` tags, parallel to the desktop app's `desktop-v*`.

Its `service do` block is an interval job, not a daemon: launchd runs
`brain vaults sync --pull` when the service loads (at `brew services start` and at
each login) and then every 600 s, as a background process, so each registry vault whose entry
sets `track` follows its branch on its own. It uses Homebrew's standard service `PATH`,
because a LaunchAgent's default `PATH` lacks `/opt/homebrew/bin`, where Homebrew's `git`
lives. Each run appends one summary line per vault to
`~/.local/state/atlas/logs/vaults-sync-service.log`; brain's own log records each run's
start and end, with timestamps. Each run starts the current keg through `opt_bin`,
so an upgrade needs no service restart.
The job gets no shell environment and runs in `/`: it reads
`~/.config/atlas/brain.config.yaml` and the Gemini key file or Keychain item, never an
`ATLAS_*` variable (`ATLAS_CONFIG`, `ATLAS_GEMINI_API_KEY`) that your shell exports.
`brew uninstall` does not stop a started service, so run `brew services stop brain` first.

## floorplan

The [`floorplan`](https://github.com/21StarkCom/floorplan) CLI (`packages/floorplan`): the
fleet's C4 design tool, built on LikeC4. It writes, checks and builds a product's C4 model
(`floorplan init`, `floorplan check`, `floorplan build`), serves it (`floorplan studio`), and
runs an MCP server.

```sh
brew install 21StarkCom/tap/floorplan
floorplan install    # register its MCP servers with Claude Code and Codex, and download the PNG export's Chromium
```

Run `floorplan install` again after each upgrade. Its `floorplan-likec4` entry names a path in
the keg's pnpm store, and that path can change with a release.

Like `librarian`, the release zip is a **`pnpm deploy` tree** (`bin/`, `kit/`, `dist/` and a
vendored `node_modules`) that the formula installs into `libexec` and wraps to run
`bin/floorplan.mjs` under the keg's `node`. It has no Mach-O of its own; its Mach-Os are the
npm prebuilds of esbuild, rollup, rolldown, lightningcss and fsevents, each with its linker's
ad hoc signature. On install, Homebrew renames each dylib to its long `opt` path, and the
rollup prebuild has no header space for it. So the formula's `install` gives the three dylibs
(rollup, rolldown, lightningcss) a short `@rpath` name and signs them ad hoc again, and
`preserve_rpath` tells Homebrew to keep that name. The GetEvinced mirror copies it: the
operator let its readable JS tree go on 2026-11-07, and the release strips the TypeScript of its
`@floorplan` packages, so the source check passes. Released from `floorplan-v*` tags by
floorplan's `scripts/release-floorplan.sh`, whose bump PR stays open for a hand merge.

## frigg

The [`frigg`](https://github.com/21StarkCom/frigg) IT-ops toolkit for Google Workspace and
the vendor fleet: the `frigg` CLI, the `frigg-cockpit` TUI, one binary per vendor module
(with a link per extra command), and two single-purpose Workspace CLIs,
`gws-align-managers` (bulk-align org-chart manager edges from a CSV) and
`gws-build-all-group` (rebuild the all-hands group from the directory). Both `gws-*` tools
dry-run by default; `--apply` mutates the live directory. The formula installs `frigg` and
every `frigg-*`, `frg-*` and `gws-*` binary in the release zip, so a vendor tool frigg
carves out of the CLI installs with no tap change. Up to `v0.63.0` the vendor binaries
and their links are all `frigg-<command>`. From frigg `v0.64.0`, each vendor tool is
`frg-<vendor>` (`frg-zoom` runs `frigg zoom`), and a vendor with several commands also
ships a `frg-<command>` link for each one. The `frigg-<command>` names go away on that
upgrade, so call `frg-<command>` or `frigg <command>` instead.

```sh
brew install 21StarkCom/tap/frigg
```

The binaries carry Go's linker **ad-hoc** signature, not a Developer ID.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/frigg-linux
```

`frigg-linux` installs the same tools from the static linux/amd64 build that frigg's
release ships beside the darwin one. It is a formula of its own for the reason
`muxctl-linux` is (see [muxctl](#muxctl)), and its binaries are unsigned. On another
platform, `go install` from the `frigg` repo.

## ghx

The [`ghx`](https://github.com/21StarkCom/github-extended) GitHub-work CLI — pull requests,
CI, Actions runs, cleanup and a fleet's repos. It holds the fleet's GitHub verbs
(`ghx pr-open`, `ghx pr-merge`, `ghx user`, …), and hands every other command to `gh`.

```sh
brew install 21StarkCom/tap/ghx
```

The release zip is a `bun build --compile` binary, Developer-ID signed + notarized, from
a `vX.Y.Z` tag of the `github-extended` repo. It is compiled with the release Mac's Homebrew
`bun`, whose build targets macOS 27.0, so the formula requires macOS 27 (Golden Gate).

`ghx` was `njord`, an app of the `idun` repo, up to 0.32.1. `formula_renames.json` maps
`njord` to `ghx` and `njord-linux` to `ghx-linux`, so `brew update` and `brew upgrade` move an
installed `njord` to `ghx` on a machine that trusts the whole tap (`brew trust --tap 21StarkCom/tap`).
Homebrew does not carry an entry's trust over to its new name: where only `21starkcom/tap/njord` is
trusted, they skip it and leave `njord` at 0.32.1. There, `brew install 21StarkCom/tap/ghx` (or
`ghx-linux`) trusts the new entry and moves the installed `njord` to it. The formulas install no
`njord` command: after the move, a script that runs `njord` must run `ghx`.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/ghx-linux
```

`ghx-linux` installs the same release's Linux x86_64 binary, which
`scripts/release-darwin.sh ghx` cross-compiles beside the macOS one from the
`vX.Y.Z` tag. It is unsigned, and a formula of its own for the reason `muxctl-linux`
is (see [muxctl](#muxctl)).

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
install a live, repo-tracking wrapper with `apps/idun/setup.sh`, which steps aside when this
formula is installed.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/idun-linux
```

`idun-linux` installs the same release's Linux x86_64 binary, which
`scripts/release-darwin.sh idun` cross-compiles beside the macOS one from the
`vX.Y.Z` tag. It is unsigned, and a formula of its own for the reason `muxctl-linux`
is (see [muxctl](#muxctl)).

## librarian

The [`librarian`](https://github.com/21StarkCom/atlas) CLI (`@atlas/librarian`): an agent
that answers questions from the Atlas vaults, through `librarian ask`, an MCP server
(`librarian mcp`, registered by `librarian install`) and a daemon.

```sh
brew install 21StarkCom/tap/librarian
brew services start librarian
brew services restart librarian    # after each upgrade: the running daemon is the old version
```

Like `brain`, the release zip is a **`pnpm deploy` tree** that the formula installs into
`libexec` and wraps to run under the keg's `node`. It depends on this tap's `brain` formula,
by its full name, and on homebrew/core's `gitleaks`, which its harvest needs to scan each
message for secrets. Its `service do` block runs `librarian daemon` with `keep_alive` and
Homebrew's standard service `PATH`, because a LaunchAgent's default `PATH` lacks
`/opt/homebrew/bin`. The daemon's log is `~/.local/state/atlas/librarian/logs/daemon.log`.
Homebrew does not restart a service on upgrade, and the upgrade's cleanup removes the old
version, so restart the service after each upgrade. The package has no Mach-O of its own;
its one Mach-O is the Agent SDK's Anthropic-signed `claude`, so it is not notarized.
Released from `librarian-v*` tags by atlas's `scripts/release-librarian.sh`.

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

From the multi-call build on, the zip holds two binaries: `lumiere-onnx`, which holds the
ONNX tools, and `lumiere`, which holds the rest. `install` reads the tool list from
`lumiere tools` and links each `lumiere-<tool>` to the binary that holds it: a tool that
`lumiere-onnx <tool> -version` runs links there, and every other tool links to `lumiere`. A
zip that ships a file for each tool (v0.9.0 and before) gets no link.

## muninn

The [`muninn`](https://github.com/21StarkCom/muninn) cross-agent messaging skill. The release
asset is the tagged bash tree; `muninn-install` runs its `install.sh`, which copies the skill
into `~/.agents/skills/muninn/`. It holds source, so `scripts/mirror.sh` excludes it.

```sh
brew install 21StarkCom/tap/muninn
muninn-install
```

Its `release.yml` bumps it with `--asset-suffix .tar.gz`.

## muxctl

The [`muxctl`](https://github.com/21StarkCom/mux-control) CLI + engine for
the [cmux](https://github.com/manaflow-ai/cmux) control API — one bun/TypeScript
binary that spawns/splits tabs, drives the per-workspace todo checklist (a one-shot
command group plus an interactive TUI), finds orphaned surface processes, and discovers
and messages peer agent sessions (`msg`).

```sh
brew install 21StarkCom/tap/muxctl
```

The release zip is a `bun build --compile` binary carrying bun's linker-signed **ad-hoc**
signature, not a Developer ID. It is compiled with the release Mac's Homebrew `bun`, whose
build targets macOS 27.0, so the formula requires macOS 27 (Golden Gate). `muxctl` reaches its
cmux app over the inherited `CMUX_SOCKET_PATH`, so run it from inside a cmux surface (or
set the socket env yourself). The formula depends on this tap's [`urd`](#urd) formula, by
its full name, because muxctl finds a repo's checkout with `urd repos get`.

`muxctl` was `hermod`, from the `hermod` repo (now `mux-control`), up to 0.52.0. Each `muxctl`
formula also installs `hermod` as a link to `muxctl`, and `formula_renames.json` maps `hermod`
to `muxctl` and `hermod-linux` to `muxctl-linux`, so `brew update` and `brew upgrade` move an
installed `hermod` to `muxctl` on a machine that trusts the whole tap (`brew trust --tap
21StarkCom/tap`). Homebrew does not carry an entry's trust over to its new name: where only
`21starkcom/tap/hermod` is trusted, they skip it and leave `hermod` at 0.52.0. There,
`brew install 21StarkCom/tap/muxctl` (or `muxctl-linux`) trusts the new entry and moves the
installed `hermod` to it.

On Linux x86_64 (the devbox), where muxctl drives tmux instead:

```sh
brew install 21StarkCom/tap/muxctl-linux
```

`muxctl-linux` installs the same `muxctl`, cross-compiled by the release Mac with
`bun build --compile --target=bun-linux-x64`. It is a formula of its own because a
formula cannot pin a url inside `on_macos`/`on_linux` blocks (`brew style` refuses it),
as mux-control's ADR 0013 records. The binary is unsigned; Linux has no Gatekeeper. It depends
on `urd-linux` for the same reason `muxctl` depends on `urd`.

## odinctl

The [`odinctl`](https://github.com/21StarkCom/odin) CLI (`@21starkcom/odinctl`): the doors
that run a playbook on the odin agent kernel, from a terminal (`odinctl run`) or on a
schedule (`odinctl schedule`).

```sh
brew install 21StarkCom/tap/odinctl
```

The formula is `odinctl`, not `odin`: homebrew/core's `odin` is the Odin language compiler.
The formula also links `odin` to `odinctl`, so it conflicts with homebrew/core's `odin`.
Like `librarian`, the release zip is a node ESM tree (`dist/`, a vendored `node_modules` with
no symlinks from `npm install --install-links --no-bin-links`, and the `conformance/` fixtures) that the formula installs into `libexec` and
wraps to run under the keg's `node`. It has no `service do` block: `odinctl schedule` writes
its own launchd plists. The package's own Mach-O files are `bin/odin-face`, the Go program
that `odinctl ui` starts, and from 0.30.0 `bin/desk`, odin's IT desk, the Go program that
`odinctl desk` and its desk rows run; the release signs both with the operator's Developer ID
and notarizes them. Its other Mach-O is the Agent SDK's Anthropic-signed `claude`. Released
from `odinctl-v*` tags by odin's `scripts/release-odinctl.sh`.

## plume

The [`plume`](https://github.com/21StarkCom/plume) pure-Go document toolkit — one
`plume-<format>` driver per format (`plume-xlsx`, `plume-docx`, `plume-pdf`,
`plume-pptx`, `plume-handwriting`), each a thin CLI over the format's library
package (the library is the product; these binaries are the drivers). From the
release that ships it, a `plume` dispatcher lists and runs the drivers.

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

sleipnir drives system Chrome on macOS, so there is no Linux build.
sleipnir's release builds each launcher (`apps/*/bin/*.mjs`) as one minified Bun bundle,
and minified bundles at `packages/huginn/src/chat.ts` and
`apps/huginn-bridge/src/journey-script.ts`, the only `.ts` files outside `node_modules`.
The release zip is that runnable tree (the bundles, their run-time files and a vendored
prod `node_modules`), whose only Mach-O are the
Developer-ID-signed darwin-arm64 `bare-fs`, `bare-path` and `bare-url` prebuilds, in a
notarized zip. The copies in the keg carry an ad hoc signature: as it installs each
prebuild, Homebrew rewrites its dylib install name and re-signs it ad hoc. The caps
`chrome-popups-dismiss`, `claude-code-terminal-login` and `mac-screenshot --app` need the
`goldfinger` cask (below), which a formula cannot depend on, and the `captcha-solve` cap
(from 0.30.0) runs `claude -p` on the operator's own Claude sign-in, so it needs Claude
Code's `claude` on `PATH`, which a formula cannot depend on either. The formula installs
the tree into `libexec` and wraps `slp` /
`sleipnir`, `huginn` (the Sleipnir Huginn browser extension's CLI, from 0.11.0) and
`sleipnir-mcp` (the MCP server an agent client runs, from 0.12.1) over Homebrew's
`bun` (a formula dependency), each keeping the caller's working-directory `.env` and
`bunfig.toml` out. Name it in full —
`brew upgrade 21StarkCom/tap/sleipnir` — since a bare `sleipnir` is homebrew/cask's
browser of the same name.

## sonar

The [`sonar`](https://github.com/21StarkCom/sonar) read-only CLI: `sonar <url>` turns a vendor
link (a Slack thread, a Jira issue, a Doc, a commit) into its content, and `sonar probe <url>`
reads what a web server sends (redirect hops, headers, cookies, DNS, TLS, CORS). 0.1.0 is the
scaffold, with `sonar --version` and `sonar --help` only; odin's
`docs/specs/2026-11-13-sonar-spec.md` is the design (epic STARK-18510).

```sh
brew install 21StarkCom/tap/sonar
```

The release zip holds only the `sonar` binary, which carries Go's linker **ad-hoc** signature,
not a Developer ID. sonar's `release.yml` builds both zips with goreleaser on Linux, and its
`bump-tap` job re-pins `sonar` and `sonar-linux`, one PR each.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/sonar-linux
```

`sonar-linux` installs the same CLI from the static linux/amd64 build that sonar's release
ships beside the darwin one. It is a formula of its own for the reason `muxctl-linux` is
(see [muxctl](#muxctl)), and its binary is unsigned. On another platform, `go build ./cmd/sonar`
in the `sonar` repo.

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

## urd

The [`urd`](https://github.com/21StarkCom/urd) local identity and infra cache: one SQLite
file, `~/Code/.localdb/cache.db`, synced from the vendors (HiBob, Google Workspace, Slack,
GitHub, ClickUp, Atlassian, PagerDuty, GCP) and read by people and tools with
`urd <verb> --json`. It took over the cache from frigg (frigg's spec
`docs/specs/2026-10-31-cache-extraction-spec.md`). The release zip's `README.md` gives
the one-time setup of a machine, which the formula does not do: the credential profiles
in `~/.config/urd/config.yaml`, and on macOS the 6h sync agent (`urd schedule install`).
Homebrew does not own that agent, so run `urd schedule uninstall` before `brew uninstall urd`.

```sh
brew install 21StarkCom/tap/urd
```

The binary carries Go's linker **ad-hoc** signature, not a Developer ID.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/urd-linux
```

`urd-linux` installs the same CLI from the static linux/amd64 build that urd's release
ships beside the darwin one. It is a formula of its own for the reason `muxctl-linux` is
(see [muxctl](#muxctl)), and its binary is unsigned. On another platform, `go install`
from the `urd` repo.

## utgard

The [`utgard`](https://github.com/21StarkCom/utgard) remote VMs — the subcommands
`utgard devbox`, `utgard winbox` and `utgard open`, which run the devbox and the winbox VMs
and open tabs on each box from the Mac. The formula puts only `utgard` on `PATH`. utgard
took over `devbox` and `winbox` from `idun`, and lives in its own repo (utgard's
`docs/specs/vm-app.md`).

```sh
brew install 21StarkCom/tap/utgard
```

The release zip is a `bun build --compile` binary, Developer-ID signed + notarized, from
a `vX.Y.Z` tag of the `utgard` repo. It is compiled with the release Mac's Homebrew
`bun`, whose build targets macOS 27.0, so the formula requires macOS 27 (Golden Gate).
Releases up to 0.11.2 came from the `utgard-vX.Y.Z` tags of the `idun` repo.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/utgard-linux
```

`utgard-linux` installs the same release's Linux x86_64 binary, which
`scripts/release-darwin.sh utgard` cross-compiles beside the macOS one from the
`vX.Y.Z` tag. It is unsigned, and a formula of its own for the reason `muxctl-linux`
is (see [muxctl](#muxctl)).

## valkyrie

The [`valkyrie`](https://github.com/21StarkCom/idun) agent launchers — the subcommands
`valkyrie klod`, `kodx`, `bob`, `agnes`, `gru` and `minion`, which start Claude Code and
Codex sessions in cmux tabs, worktrees and tickets. The formula puts only `valkyrie` on
`PATH`. It is the third app of the `idun` repo, and takes over the launch commands from
`idun` (idun's `docs/specs/launcher-app.md`).

```sh
brew install 21StarkCom/tap/valkyrie
```

The release zip is a `bun build --compile` binary, Developer-ID signed + notarized, from
a `valkyrie-vX.Y.Z` tag of the `idun` repo. It is compiled with the release Mac's Homebrew
`bun`, whose build targets macOS 27.0, so the formula requires macOS 27 (Golden Gate). A
checkout of the `idun` repo can instead install a live, repo-tracking wrapper with
`apps/idun/setup.sh`, which steps aside when this formula is installed.

Name it in full — `brew upgrade 21StarkCom/tap/valkyrie` — since a bare `valkyrie` is also
homebrew/cask's Valkyrie, a game master app for board games: `brew uninstall valkyrie`
warns that it treats the name as a formula, and `--formula` silences that.

On Linux x86_64 (the devbox):

```sh
brew install 21StarkCom/tap/valkyrie-linux
```

`valkyrie-linux` installs the same release's Linux x86_64 binary, which
`scripts/release-darwin.sh valkyrie` cross-compiles beside the macOS one from the
`valkyrie-vX.Y.Z` tag. It is unsigned, and a formula of its own for the reason `muxctl-linux`
is (see [muxctl](#muxctl)).

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
trajectories and videos under `recordings/`),
`~/Library/Group Containers/MG9J2XF9Q3.com.21stark.goldfinger` (from 0.13.0 on, the app group
container of the Safari extension, whose `replies/` folder can hold a page's text; dev builds
share it), `~/Library/Containers/com.21stark.goldfinger.SafariExtension` (the extension's own
sandbox container; a dev build's `.dev` container stays), the empty folders macOS makes for both
containers under `~/Library/Application Scripts` and the helper's
`~/Library/Preferences/com.21stark.goldfinger.control.plist`.
Homebrew zaps by the list the install recorded, so an install made before the tap named a
container keeps it: run `brew reinstall --cask 21StarkCom/tap/goldfinger` before the zap, or
trash the container by hand. A terminal without Full Disk Access can meet
`Operation not permitted` on another app's sandbox container, even under `sudo`
([homebrew/cask#201201](https://github.com/Homebrew/homebrew-cask/issues/201201)). The zap
then stops with Homebrew's "Please enable Full Disk Access for your terminal", or warns that
the path "could not be trashed": give your terminal Full Disk Access (System Settings →
Privacy & Security), then run the zap again with `--force`. Neither the uninstall nor
`--zap` revokes the grants: remove Goldfinger in System Settings → Privacy & Security, or run
`tccutil reset Accessibility com.21stark.goldfinger` and
`tccutil reset ScreenCapture com.21stark.goldfinger`.

## idavoll (workspace installer — cask)

The 21Stark workspace installer from [`idavoll`](https://github.com/21StarkCom/idavoll):
`Idavoll.app` and its `idavoll` CLI. The cask installs the release's own `.pkg`, the package
a bare Mac installs from the GitHub release, so both routes write the same files:
`/Applications/Idavoll.app` and `/usr/local/bin/idavoll`, under the package id
`com.21stark.idavoll`. The package installs as root, so the install and each upgrade ask for
the `sudo` password. A bare Mac has no Homebrew yet (idavoll installs it), so it still takes
the `.pkg` from the release.

```sh
brew install --cask 21StarkCom/tap/idavoll
brew install --cask getevinced/tap/idavoll   # with read access to GetEvinced/homebrew-tap only
```

The file is `Casks/i/idavoll.rb`, not `Casks/idavoll.rb`. idavoll's Fleet CLIs step installs
each `Casks/*.rb` of this tap, so it would install idavoll's own `.pkg` in the middle of its
own run, and the package's preinstall quits a running Idavoll.app. Homebrew reads
`Casks/**/*.rb`; idavoll reads `Casks/*.rb` only. The GetEvinced mirror copies this cask to
the same path in `GetEvinced/tap`, `.pkg` included: on 2026-10-31 the operator accepted the
readable JavaScript in its `app.asar` there (spec D11, STARK-14490).

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
but leaves the service, the menu's login item and, while sync is on, the Mímir Sync helper
registered with launchd; `brew uninstall --zap --cask 21StarkCom/tap/mimir` also removes them all
(`zap launchctl:`) and trashes its local data (but never the login-Keychain vault key — that is
the app's own Danger Zone → Erase Everything). Once a plain uninstall has run, add `--force`, and
keep the full name: that uninstall drops Homebrew's trust in the cask, and an untrusted tap's cask
loads only when named in full.

## Repo layout

| Path | What it holds |
|---|---|
| `Formula/` | One Ruby formula per CLI, plus eight `<tool>-linux` formulae (`muxctl-linux`, `frigg-linux`, `urd-linux`, `idun-linux`, `ghx-linux`, `valkyrie-linux`, `utgard-linux`, `sonar-linux`), their tools' Linux builds. |
| `Casks/` | One cask per GUI app. The idavoll cask is in `Casks/i/`, which idavoll's installer does not read. |
| `formula_renames.json` | Homebrew's map of renamed formulae: `njord` → `ghx`, `njord-linux` → `ghx-linux`, `hermod` → `muxctl`, `hermod-linux` → `muxctl-linux`. |
| `scripts/bump.sh` | The bumper: re-pins one entry to a published release and opens the PR. `--help` is its reference. |
| `scripts/test-bump.sh` | The bumper's tests, against a bare remote and a stubbed `gh`. |
| `scripts/mirror.sh` | The mirror: copies every entry, with its release asset, into `GetEvinced/homebrew-tap`; a public entry's copy keeps its url. `--help` is its reference. |
| `scripts/source-check.pl` | The source check of a release asset: the mirror runs it on each copy, and the bumper on each public entry's asset before it publishes one. |
| `scripts/test-mirror.sh` | The mirror's tests, against a bare remote and a stubbed `gh`. |
| `docs/specs/getevinced-mirror.md` | The design of the GetEvinced mirror (epic STARK-13601). |
| `docs/specs/public-tap.md` | The design of the public entries (STARK-19553). |
| `scripts/verify-auth.rb` | Checks that each public entry downloads with no token, with gh's login hidden, and the missing and whitespace-only token errors of a private entry (none today), with synthetic credentials only. |
| `scripts/verify-download.rb` | Checks muxctl's preflight and a partial-download resume against the pinned checksum. |
| `.github/workflows/formulae.yml` | On ubuntu arm64 (Homebrew on Linux): styles every entry, runs both verify scripts, and audits and fetches every formula and cask. |
| `.github/workflows/bump.yml` | Runs `scripts/test-bump.sh` on ubuntu, and under bash 3.2 in the `bash:3.2` image (with no `.pkg` test), and `scripts/test-mirror.sh` on ubuntu. |
| `.github/workflows/mirror.yml` | On each push to `main`, daily and by hand: runs `scripts/mirror.sh` as the `21stark-tap-mirror` App, then fetches the changed copies (every copy, daily and by hand) from GetEvinced. |
| `.github/workflows/secret-scan.yml` | The fleet's shared secret scan. |

## How it fits the fleet

The tap is a passive publish target. Each source repo's release re-pins its own entry by
running this repo's `scripts/bump.sh` (21stark ADR-0008), which reads the asset and its
checksum back from the published release, publishes the asset as a release of this tap,
and opens a PR here. Two entries have no release
that bumps them: the atlas cask, re-pointed by hand at a `desktop-v*` release, and tyr, a
frozen v0.109.0 CLI from before tyr became library-only.

Every push to `main` also reaches [`GetEvinced/homebrew-tap`](https://github.com/GetEvinced/homebrew-tap)
(`GetEvinced/tap`), for Evinced engineers. `mirror.yml` writes each entry there with
`21StarkCom/tap` renamed to `GetEvinced/tap`
([the spec](docs/specs/getevinced-mirror.md)). It writes only files that hold its marker
line, its own block of the README there, and its own pairs in `formula_renames.json` and
`cask_renames.json` (spec D13), so the Evinced team's own `aac` and `evinced` stay theirs,
and it deletes no release. A rename here, such as `njord` to `ghx`, so reaches GetEvinced,
and `brew update` moves an install of the old name there too.
A public entry's copy keeps its url, and no asset is copied for it; so today no asset is copied.
For a private entry, it copies the release asset into a release there and points the copy's
URL at it. Before each upload it unpacks the asset and refuses one that holds source (spec D12; the
rules are in `scripts/source-check.pl`, which the bumper also runs before it publishes an asset here):
outside `node_modules`, a `.ts`, `.tsx`, `.mts` or `.cts` file (but a `.d.ts`, and a
minified bundle at a path the entry names under `libexec`), a `.map` file, or a `.json`
that holds `sourcesContent`; in a package of a first-party scope (`@21starkcom`, `@atlas`,
`@floorplan`, `@idun`, `@sleipnir`) under `node_modules`, those files or any `sourcesContent`; and an
inline source map in either place. Extensions match in any case. A refused entry is not
copied, and the run fails. `scripts/mirror.sh --check <entry> <archive>` runs the same
check on a local zip, `.tar.gz` or `.pkg`, with no token, so a release can run it before it
ships. A `.pkg` is a xar archive: `bsdtar` unpacks it and each `Payload` and `Scripts` in it,
and the check reads the files. The check cannot judge readable JS (an unminified bundle,
the JS inside a compiled binary, or an Electron `app.asar`, which it reads as one file).
`alfred` stays out by the operator's request (spec D11), and `muninn` because its asset is
its bash source tree. A new entry goes there unless its PR adds it to `EXCLUDED` in
`scripts/mirror.sh`. The mirror reads `Casks/*.rb` and
`Casks/*/*.rb`, so it copies the idavoll cask (`Casks/i/idavoll.rb`) to the same path there.

### Public entries

Every entry is public: anyone installs it with no GitHub login, because each downloads
from a public release of this tap ([the spec](docs/specs/public-tap.md)). The source repos
stay private. A public entry's `url` is
`https://github.com/21StarkCom/homebrew-tap/releases/download/<entry>-v<version>/<asset>`, and
its line `# Source release repo: <owner>/<repo>` names the repo whose release the bumper reads.
The bumper checks the asset with `scripts/source-check.pl`, publishes it as that release of
this tap, then pins it. A public asset cannot be called back. The operator let readable JS
and shell source go public (the node trees, the Bun bundles, the Electron app and `muninn`),
but never a secret: scan a new entry's asset with `gitleaks` before its first publish. A new
entry starts public.

An entry whose asset holds a secret stays private, in the shape that the bumper and
`scripts/verify-auth.rb` still support. Its `url` is the GitHub API URL of its source repo's
asset, with an `Accept: application/octet-stream` header and a token from Homebrew's own
lookup (`GitHub::API.credentials`): `HOMEBREW_GITHUB_API_TOKEN`, else Homebrew's gh login,
else a keychain token. A formula passes them as `headers:` on its `url`, skips the lookup in
Homebrew's sandboxed build, test and postinstall workers (and `sandbox_operation.rb`, for a
formula that renames a dylib), matched by full path under `HOMEBREW_LIBRARY_PATH`, never by
`ENV`, which Homebrew restores after it evaluates a formula. It raises
`CurlDownloadStrategyError` with setup guidance when the lookup finds nothing. A cask sets
them in an initialization-only download adapter, so `brew info --json` shows no credential.
Homebrew redacts only `ENV` secrets: with a gh-only login, `--verbose --debug` output shows
the gh token. Git history before STARK-19636 holds each shape (`Formula/idun.rb`, `Casks/atlas.rb`).

On a bare Mac, [idavoll](https://github.com/21StarkCom/idavoll)'s installer reads `Formula/`
and `Casks/` from its clone of this repo and installs every entry, so a new entry reaches the
next rebuilt machine with no change to the installer. It leaves out every formula that
declares `depends_on :linux` (the eight `-linux` formulae), and it does not read the
folders inside `Casks/`, so it never installs the idavoll cask (`Casks/i/idavoll.rb`). idavoll's devbox profile
works the other way: it installs, builds or skips each entry as idavoll's
`config/linux-clis.json` says, and reports a failure for an entry that file does not
list, so a new entry needs its line there too (STARK-11780 places `frigg-linux`).

## Releases: who bumps each entry

Each entry pins three release-specific lines: `version`, its `url` (the URL of its
release of this tap), and `sha256`. Do **not** hand-edit them. The source repo's release step calls the
bumper, which reads them back from the published GitHub Release and opens a PR here.
`scripts/bump.sh --help` is the bumper's reference, and CLAUDE.md says how to run it by hand.

| Entry | Source repo | Release step that calls the bumper | Runs on |
|---|---|---|---|
| `agent-seats` | agent-seats | `scripts/release-darwin.sh` | the signing Mac |
| `alfred` | odin | `packages/toolbox/scripts/release-darwin.sh` (run by `make -C packages/toolbox ship`), for an `alfred-v*` tag | the signing Mac |
| `bragi` | bragi | `scripts/release-darwin.sh` | the signing Mac |
| `brain` | atlas | `scripts/release-darwin.sh`, for a `cli-v*` tag | the signing Mac |
| `floorplan` | floorplan | `scripts/release-floorplan.sh`, for a `floorplan-v*` tag | the operator's Mac |
| `frigg` | frigg | `.github/workflows/release.yml` | GitHub Actions |
| `frigg-linux` | frigg | `.github/workflows/release.yml` `publish` (`--asset-suffix linux_amd64.zip`) | GitHub Actions |
| `ghx` | github-extended | `scripts/release-darwin.sh ghx`, for a `v*` tag | the signing Mac |
| `ghx-linux` | github-extended | `scripts/release-darwin.sh ghx` (`--asset-suffix linux_x64.zip`) | the signing Mac |
| `heimdall` | heimdall | `scripts/release-darwin.sh` | the signing Mac |
| `idun` | idun | `scripts/release-darwin.sh` | the signing Mac |
| `idun-linux` | idun | `scripts/release-darwin.sh` (`--asset-suffix linux_x64.zip`) | the signing Mac |
| `librarian` | atlas | `scripts/release-librarian.sh`, for a `librarian-v*` tag | the signing Mac |
| `lumiere` | lumiere | `scripts/release-darwin.sh` | the signing Mac |
| `muninn` | muninn | `.github/workflows/release.yml` (`--asset-suffix .tar.gz`) | GitHub Actions |
| `muxctl` | mux-control | `ts/scripts/release-darwin.sh` | the signing Mac |
| `muxctl-linux` | mux-control | `ts/scripts/release-darwin.sh` (`--asset-suffix linux_x64.zip`) | the signing Mac |
| `odinctl` | odin | `scripts/release-odinctl.sh`, for an `odinctl-v*` tag | the signing Mac |
| `plume` | plume | `.github/workflows/release.yml` | GitHub Actions |
| `sleipnir` | sleipnir | `scripts/release-darwin.sh` | the signing Mac |
| `sonar` | sonar | `.github/workflows/release.yml` `bump-tap` | GitHub Actions |
| `sonar-linux` | sonar | `.github/workflows/release.yml` `bump-tap` (`--asset-suffix linux_amd64.zip`) | GitHub Actions |
| `stark-statusline` | idavoll | `statusline/release.sh` (`make statusline-release STATUSLINE_VERSION=X.Y.Z`), for a `statusline-v*` tag | the operator's Mac |
| `tyr` | tyr | none: tyr is library-only and ships no binary, so the formula stays on its last CLI release | — |
| `urd` | urd | `scripts/release.sh`, after its tag's `.github/workflows/release.yml` publishes | the devbox |
| `urd-linux` | urd | `scripts/release.sh` (`--asset-suffix linux_amd64.zip`) | the devbox |
| `utgard` | utgard | `scripts/release-darwin.sh utgard`, for a `v*` tag | the signing Mac |
| `utgard-linux` | utgard | `scripts/release-darwin.sh utgard` (`--asset-suffix linux_x64.zip`) | the signing Mac |
| `valkyrie` | idun | `scripts/release-darwin.sh valkyrie`, for a `valkyrie-v*` tag | the signing Mac |
| `valkyrie-linux` | idun | `scripts/release-darwin.sh valkyrie` (`--asset-suffix linux_x64.zip`) | the signing Mac |
| `atlas` (cask) | atlas | none: no release step bumps it, so re-point it by hand at a `desktop-v*` release (`--asset-suffix .zip`) | — |
| `goldfinger` (cask) | goldfinger | `macos/scripts/release-darwin.sh` | the signing Mac |
| `idavoll` (cask) | idavoll | the Mac release steps in `mac/README.md`, after the publish of a `mac-v*` tag (`--asset-suffix .pkg`) | the operator's Mac |
| `mimir` (cask) | mimir | `scripts/release-darwin.sh` | the signing Mac |

agent-seats', idun's (`idun` and `valkyrie`, and each one's `-linux` formula), github-extended's (`ghx` and `ghx-linux`), utgard's (`utgard` and `utgard-linux`), alfred's and urd's (`urd` and `urd-linux`) releases and plume's, frigg's, muninn's and sonar's `release.yml` merge their
own bump PRs unattended (frigg's two: `frigg` and `frigg-linux`; sonar's two: `sonar` and `sonar-linux`): `bump.sh --merge` waits for every
check here first. frigg's run leaves its PRs open, under a warning, while its token lacks
Actions: read on this tap. Every other bump PR stays open for a hand merge with
`ghx pr-merge`, titled `chore(STARK-<n>): …` when a ticket covers it and labeled
`no-ticket` (by `bump.sh`) while its title names no ticket.

## Download authentication and CI

Every entry downloads from a public release of this tap and holds no token code; all network operations remain Homebrew's, which handles redirects, cache freshness, and partial resume. [Public entries](#public-entries) describes the private shape that an entry with a secret in its asset would take.

Pull requests run on ubuntu arm64, under Homebrew on Linux: `brew style`, a no-token download of each changed entry, and `brew audit --strict` and `brew fetch` for every formula, which checks its download against the pinned `sha256`; each `<tool>-linux` formula (`muxctl-linux`, `frigg-linux`, `urd-linux`, `idun-linux`, `ghx-linux`, `valkyrie-linux`, `utgard-linux`, `sonar-linux`) is audited as Linux x86_64, and CI requires its fetch to have downloaded a Linux x86-64 `<tool>`. Every cask is fetched, which checks its download against the pinned `sha256`, and strict-audited with `brew audit --cask --strict`, skipping only `sha256_no_check_if_unversioned` (plus `token_conflicts` for atlas). A separate muxctl download check verifies the preflight and a partial resume against the release checksum. Every entry but the eight `-linux` formulae is macOS-only, and those are x86_64-only on the arm runner, so CI installs and tests none of them; `brew reinstall` and `brew test` do, on a Mac, and on the x86_64 devbox for the `-linux` formulae. The `bump` workflow runs the bumper's tests (`scripts/test-bump.sh`) on ubuntu, and under bash 3.2 in the `bash:3.2` image. CI's fetch steps pass the repository Actions secret `HOMEBREW_RELEASE_READ_TOKEN` as the token, which a private entry needs, with read access to its source repo; with the secret empty, as on a PR from a fork, they fetch with no token.
