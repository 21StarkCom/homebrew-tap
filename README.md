# homebrew-tap

Private [Homebrew](https://brew.sh) tap for the 21Stark fleet.

## idun

The [`idun`](https://github.com/21StarkCom/idun) personal-ops maintenance CLI —
one bun/TypeScript binary, one subcommand per tool (GitHub identity swap, seat
rotation, cleanup, housekeeping, updates).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/idun
```

The token is required: this repo and the `idun` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). The release zip is a `bun build --compile`
binary carrying bun's linker-signed **ad-hoc** signature — it runs under Homebrew
(which strips the quarantine xattr) but is **not** Developer-ID notarized like
the tools below, so a raw unzip outside Homebrew hits Gatekeeper. The live,
repo-tracking install is the wrapper in the `idun` repo (`./setup.sh`); this
formula is for repo-less machines.

## hermod

The [`hermod`](https://github.com/21StarkCom/hermod) CLI + engine for
the [cmux](https://github.com/manaflow-ai/cmux) control API — one bun/TypeScript
binary that spawns/splits tabs, drives the per-workspace todo checklist (a one-
shot command group plus an interactive TUI), and finds orphaned surface
processes.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/hermod
```

The token is required: this repo and the `hermod` releases are **private**,
and the entry's native Homebrew downloader fetches the release asset by
its GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Same ad-hoc signature story as `idun`: the
release zip is a `bun build --compile` binary carrying bun's linker-signed
**ad-hoc** signature — it runs under Homebrew (which strips the quarantine
xattr) but is **not** Developer-ID notarized, so a raw unzip outside Homebrew
hits Gatekeeper. `hermod` reaches its cmux app over the inherited
`CMUX_SOCKET_PATH`, so run it from inside a cmux surface (or set the socket env
yourself).

## frigg

The [`frigg`](https://github.com/21StarkCom/frigg) 21Stark IT-ops CLIs for Google
Workspace — `gws-align-managers` (bulk-align org-chart manager edges) and
`gws-build-all-group` (maintain `all@evinced.com` as a group-of-groups). Both
dry-run by default; `--apply` mutates the live directory.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/frigg
```

The token is required: this repo and the `frigg` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Like `idun`, the release zip is
**ad-hoc-signed** (Go's linker), **not** Developer-ID notarized — it runs under
Homebrew (which strips the quarantine xattr) but a raw unzip outside Homebrew
hits Gatekeeper. Non-macOS or repo-less: `go install` from the `frigg` repo.

## lumiere

The [`lumiere`](https://github.com/21StarkCom/lumiere) visual-media CLI toolkit —
the `lumiere-*` tools (image gen/edit, SVG suite, video, brand icons, …), fronted
by a `lumiere` dispatcher (`lumiere <tool> [args]`, `lumiere --help` for the list).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/lumiere
```

The token is required: this repo and the `lumiere` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS 26 (Tahoe) arm64 only.** The ONNX tools (`lumiere-bg`, `lumiere-bg-swap`,
`lumiere-product`, `lumiere-upscale`) are built for macOS 26.0. The bottle is a Developer-ID-signed + notarized
`darwin_arm64` build (Apple Silicon). Linux users build from source in the
`lumiere` repo (`make build`).

## sleipnir

The [`sleipnir`](https://github.com/21StarkCom/sleipnir) CLI — drives dedicated,
persistent Chrome profiles for ad-hoc agent tasks (per-task user-agent, headless
or headed, plus a suite of capabilities).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/sleipnir
```

The token is required: this repo and the `sleipnir` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by
its GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). sleipnir drives system Chrome and a Swift
AX/CGEvent helper, so there is no Linux build. sleipnir has **no build step** —
Bun runs its TypeScript directly — so the release zip is the runnable tree
(source + a vendored prod `node_modules`) plus the Developer-ID-signed + notarized
Swift `mac-helper`. The formula installs the tree into `libexec` and wraps `slp` /
`sleipnir`, `huginn` (the Sleipnir Huginn browser extension's CLI, from 0.11.0) and
`sleipnir-mcp` (the MCP server an agent client runs, from 0.12.1) over Homebrew's
`bun` (a formula dependency), each keeping the caller's working-directory `.env` and
`bunfig.toml` out. Name it in full —
`brew upgrade 21StarkCom/tap/sleipnir` — since a bare `sleipnir` is homebrew/cask's
browser of the same name.

## lucius

The [`lucius`](https://github.com/21StarkCom/lucius) CLI — a terminal brainstorming
partner on the Claude Agent SDK that recalls from `brain` and keeps its own vault.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/lucius
```

The token is required: this repo and the `lucius` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Same shape as `sleipnir`: Bun runs the
TypeScript directly, so the release zip is the runnable tree (`bin/`, `src/`,
`package.json`, `bun.lock`) plus a vendored prod `node_modules`. The formula
installs it into `libexec` and wraps `lucius` over Homebrew's `bun` (a formula
dependency), which must be **1.4.2 or newer** — lucius refuses to start on an
older one, so `brew upgrade bun` if you are behind. Homebrew cannot express that
floor on a formula dependency, so `brew install` succeeds and the refusal only
shows on the first run. The tree's one Mach-O is the Agent SDK's own `claude`
binary, signed by Anthropic; `src/vault/publication.c` ships beside its loader
because `bun:ffi` compiles it at runtime.

The wrapper runs `bun --no-env-file --config=/dev/null`, so the caller's working
directory can't inject a `.env` or a `bunfig.toml` preload into lucius.

## mimir

[`mimir`](https://github.com/21StarkCom/mimir) — a personal macOS credential vault
with a paired `mimir` CLI and a loopback MCP server for agents. Unlike the CLIs above,
it is a **GUI app**, so it ships as a **cask** (`Casks/mimir.rb`):

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install --cask 21StarkCom/tap/mimir
```

The cask drops `Mimir.app` into `/Applications` and symlinks the bundled `mimir` CLI onto
your `PATH`. The token is required: this repo and the `mimir` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its GitHub API URL with
an `Authorization` header.

**macOS 26 (Tahoe) arm64 only** (Apple Silicon). The release zip is the Developer-ID-signed,
notarized, and **stapled** `Mimir.app`, so Gatekeeper validates it offline. `brew uninstall
--cask mimir` removes the app; `--zap` also trashes its local data (but never the
login-Keychain vault key — that is the app's own Danger Zone → Erase Everything).

## heimdall

The [`heimdall`](https://github.com/21StarkCom/heimdall) CLI — personal
native-APNs push relay. `heimdall send <title>` fires a Mac banner **and** pushes
to your iPhone / iPad via your own APNs key and app (no third-party push service).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/heimdall
```

The token is required: this repo and the `heimdall` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). The zip is the Developer-ID-signed +
notarized `heimdall` binary. Config (backend URL + send-secret) reads from the
login Keychain (service `heimdall`), or `HEIMDALL_URL` / `HEIMDALL_SEND_SECRET`.

## plume

The [`plume`](https://github.com/21StarkCom/plume) pure-Go document toolkit — one
`plume-<format>` driver per format (`plume-xlsx`, `plume-docx`, `plume-pdf`,
`plume-pptx`, `plume-handwriting`), each a thin CLI over the format's library
package (the library is the product; these binaries are the drivers).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/plume
```

The token is required: this repo and the `plume` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon) — matching the rest of this tap. plume is
`CGO_ENABLED=0` pure Go and its `release.yml` genuinely cross-compiles
`{linux,darwin}/{amd64,arm64}`, so a non-Mac (or Intel Mac) can `make build` /
`go install` straight from the `plume` repo; the formula pins the darwin/arm64
tarball only. That build carries Go's linker **ad-hoc** signature (not Developer-ID
notarized), so it runs under Homebrew (which strips the quarantine xattr) but a
raw untar outside Homebrew hits Gatekeeper.

## brain

The [`brain`](https://github.com/21StarkCom/atlas) CLI — the **Atlas** engine
(`@atlas/cli`): ingest notes, build the retrieval index, query/answer over a
vault, and run the review/housekeep surfaces.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/brain
```

The token is required: this repo and the `atlas` releases are **private**, and
the entry's native Homebrew downloader fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Unlike the bun-compiled CLIs, `brain` is
**node ESM** inside a pnpm monorepo, so the release zip is a **`pnpm deploy`
tree** — `dist/`, a vendored `node_modules` (workspace `@atlas/*` deps plus the
two used native modules, `better-sqlite3` and `@lancedb/lancedb-darwin-arm64`;
LanceDB's optional ML embedding stack is pruned), and the runtime command
registry at `docs/specs/cli-contract/`. The formula installs that tree into
`libexec`, wraps `brain` to run under the keg's `node`, and pins `ATLAS_ROOT` so
the registry always resolves. The natives are **Developer-ID signed + notarized**
(submission recorded in the `21StarkCom/apple-developer` ledger). A CLI zip can't
be offline-**stapled**, so it's online-notarized — moot under Homebrew, which
strips the quarantine xattr anyway. Released from `cli-v*` tags, parallel to the
desktop app's `desktop-v*`.

## atlas (desktop app — cask)

The **Atlas** desktop app — the GUI companion to the `brain` CLI (same
`21StarkCom/atlas` repo). A GUI `.app`, so it ships as a **cask**:

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install --cask 21StarkCom/tap/atlas
```

`Atlas.app` lands in `/Applications`. The bundle carries its own internal CLI
closure (a standalone Node + `brain` bin it spawns for status checks), so — unlike
`mimir` — the cask exposes **no `binary`**: `brain` is its own formula and must not
be shadowed. **macOS 12+ arm64.** The build is Developer-ID **signed + notarized**
(`spctl` reports "Notarized Developer ID"); `brew install --cask` strips the
quarantine xattr, so Gatekeeper never gates it. Released from the source repo's
`desktop-v*` tags (parallel to the CLI's `cli-v*`).

## goldfinger (background computer use — cask)

[`goldfinger`](https://github.com/21StarkCom/goldfinger) — background computer use for
agents: `Goldfinger.app` runs the daemon that holds the macOS grants, and the `goldfinger`
CLI observes and operates native apps without taking the user's focus or moving the cursor.
The daemon is a GUI app, so it ships as a **cask** (`Casks/goldfinger.rb`):

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install --cask 21StarkCom/tap/goldfinger
goldfinger setup      # once: grant Accessibility and Screen Recording
```

The cask drops `Goldfinger.app` into `/Applications` and symlinks its executable, which is
both the daemon and the CLI, onto your `PATH` as `goldfinger`. **macOS 26 (Tahoe) arm64
only.** The release zip is the Developer-ID-signed, notarized and **stapled**
`Goldfinger.app`. Homebrew installs it quarantined, so macOS may first ask whether to open
Goldfinger: allow it, and re-run `goldfinger setup` if it gave up waiting for the daemon.

`brew upgrade` quits the running daemon (`uninstall quit:`), then reopens the app by bundle id,
which serves as the new daemon. On a Mac that also holds dev builds (same bundle id),
LaunchServices may reopen one of those instead: run `goldfinger stop`, and the next `goldfinger`
command starts the installed one. `brew uninstall --cask goldfinger` quits the daemon and
removes the app and its link; `--zap` also trashes `~/Library/Caches/goldfinger` (socket,
lock, screenshots) and `~/Library/Application Support/goldfinger` (the snapshot epoch).
Neither revokes the grants: remove Goldfinger in System Settings → Privacy & Security, or run
`tccutil reset Accessibility com.21stark.goldfinger` and
`tccutil reset ScreenCapture com.21stark.goldfinger`.

## Releases: who bumps each entry

Each entry pins three release-specific lines: `version`, the release asset's id in its
`url`, and `sha256`. Do **not** hand-edit them. The source repo's release step calls the
bumper, which reads them back from the published GitHub Release and opens a PR here.
`scripts/bump.sh --help` is the bumper's reference, and CLAUDE.md says how to run it by hand.

| Entry | Source repo | Release step that calls the bumper | Runs on |
|---|---|---|---|
| `alfred` | alfred | `.github/workflows/release.yml`; `scripts/release-darwin.sh` | GitHub Actions; the signing Mac |
| `brain` | atlas | `scripts/release-darwin.sh`, for a `cli-v*` tag | the signing Mac |
| `frigg` | frigg | `.github/workflows/release.yml` | GitHub Actions |
| `heimdall` | heimdall | `scripts/release-darwin.sh` | the signing Mac |
| `hermod` | hermod | `ts/scripts/release-darwin.sh` | the signing Mac |
| `idun` | idun | `.github/workflows/release.yml`; `scripts/release-darwin.sh` | GitHub Actions; the signing Mac |
| `lucius` | lucius | `scripts/release-darwin.sh` | the signing Mac |
| `lumiere` | lumiere | `scripts/release-darwin.sh` | the signing Mac |
| `plume` | plume | `.github/workflows/release.yml` | GitHub Actions |
| `sleipnir` | sleipnir | `scripts/release-darwin.sh` | the signing Mac |
| `tyr` | tyr | `scripts/release-darwin.sh`; `scripts/release-tyr-darwin.sh` | the signing Mac |
| `atlas` (cask) | atlas | none: no release step bumps it, so re-point it by hand at a `desktop-v*` release | — |
| `goldfinger` (cask) | goldfinger | `macos/scripts/release-darwin.sh` | the signing Mac |
| `mimir` (cask) | mimir | `scripts/release-darwin.sh` | the signing Mac |

idun's and alfred's releases and plume's `release.yml` merge their own bump PR once this
tap's checks pass. Every other bump PR stays open until someone merges it with
`idun gh pr-merge`, under a ticket-scoped title.

## Download authentication and CI

All entries use native download auth headers, including preflight metadata requests. Formulae declare URL `headers:` directly. Casks use initialization-only adapters so tokens are never serialized in cask JSON; all network operations remain Homebrew's. Homebrew handles redirects, cache freshness, and partial resume. Tokens are stripped before use; absent or whitespace-only tokens report the asset URL and setup guidance. Formula validation happens during evaluation, so formula metadata commands require the token too. Casks validate when their downloader is initialized.

Pull requests run `brew style`, missing-token checks, and `brew audit --strict`, `brew install`, and `brew test` for every formula on macOS arm64. A separate hermod download check verifies authenticated metadata and partial resume against the release checksum. The `bump` workflow runs the bumper's tests (`scripts/test-bump.sh`) on ubuntu and macOS. CI uses the repository Actions secret `HOMEBREW_RELEASE_READ_TOKEN`, with read access to the private release repositories.
