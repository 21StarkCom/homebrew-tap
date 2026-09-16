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
the formula's `IdunPrivateReleaseStrategy` fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). The release zip is a `bun build --compile`
binary carrying bun's linker-signed **ad-hoc** signature — it runs under Homebrew
(which strips the quarantine xattr) but is **not** Developer-ID notarized like
the tools below, so a raw unzip outside Homebrew hits Gatekeeper. The live,
repo-tracking install is the wrapper in the `idun` repo (`./setup.sh`); this
formula is for repo-less machines.

## Maintenance — the idun formula is bumped automatically

`Formula/idun.rb` pins the release's darwin zip **asset id + sha256**, both of
which change every release. Do **not** hand-edit them. They are rewritten by
`idun`'s release tooling:

- `scripts/release-darwin.sh <version>` (run on a Mac) builds, ad-hoc signs,
  zips, and uploads the macOS zip onto the GitHub Release, then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from
  the published release, rewrites the three release-specific lines, and opens a
  PR here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>`
from the `idun` checkout (`--dry-run` to preview).

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
and the formula's `HermodPrivateReleaseStrategy` fetches the release asset by
its GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Same ad-hoc signature story as `idun`: the
release zip is a `bun build --compile` binary carrying bun's linker-signed
**ad-hoc** signature — it runs under Homebrew (which strips the quarantine
xattr) but is **not** Developer-ID notarized, so a raw unzip outside Homebrew
hits Gatekeeper. `hermod` reaches its cmux app over the inherited
`CMUX_SOCKET_PATH`, so run it from inside a cmux surface (or set the socket env
yourself).

## Maintenance — the hermod formula is bumped automatically

`Formula/hermod.rb` pins the release's darwin zip **asset id + sha256** and the
**version**, all of which change every release. Do **not** hand-edit them. They
are rewritten by `hermod`'s release tooling, which lives under `ts/`:

- `ts/scripts/release-darwin.sh <version>` (run on a Mac) builds, ad-hoc signs,
  zips, and uploads the macOS zip onto the GitHub Release, then calls…
- `ts/scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from
  the published release and rewrites the three release-specific lines.

Its auto-PR title is `chore: bump hermod to v<x>`, which carries no
ticket and so fails this repo's `requireTicketScope` gate. Run
`ts/scripts/bump-tap.sh <version> --no-pr --tap-dir <checkout>` instead, then open
the generated change with `idun gh pr-open` under a `chore(STARK-<n>):` title.

To re-point at an existing release by hand, run `ts/scripts/bump-tap.sh <version>`
from the `hermod` checkout (`--dry-run` to preview).

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
the formula's `FriggPrivateReleaseStrategy` fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Like `idun`, the release zip is
**ad-hoc-signed** (Go's linker), **not** Developer-ID notarized — it runs under
Homebrew (which strips the quarantine xattr) but a raw unzip outside Homebrew
hits Gatekeeper. Non-macOS or repo-less: `go install` from the `frigg` repo.

## Maintenance — the frigg formula is bumped automatically (by GitLab CI)

`Formula/frigg.rb` pins the release's darwin zip **asset id + sha256** and
**version**, all of which change every release. Do **not** hand-edit them. Unlike
the other tools here (local Mac scripts / GitHub Actions), frigg is built and
published by a **GitLab CI/CD pipeline** on the self-hosted `gitlab.evinced.cloud`
(STARK-1193). Pushing a tag `vX.Y.Z` to `21StarkCom/frigg` runs the pipeline,
which:

- cross-builds the ad-hoc-signed darwin/arm64 zip on a Linux runner
  (`frigg/scripts/build-darwin.sh`), uploads it onto the GitHub Release, then…
- runs `frigg/scripts/bump-tap.sh`, which reads the asset id + sha256 back from
  the published release, rewrites the three release-specific lines, and opens a
  PR here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>`
from the `frigg` checkout (`--dry-run` to preview).

## lumiere

The [`lumiere`](https://github.com/21StarkCom/lumiere) visual-media CLI toolkit —
16 `lumiere-*` tools (image gen/edit, SVG suite, video, brand icons, …).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/lumiere
```

The token is required: this repo and the `lumiere` releases are **private**, and
the formula's `GitHubPrivateReleaseStrategy` fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only.** The bottle is a Developer-ID-signed + notarized
`darwin_arm64` build (Apple Silicon). Linux users build from source in the
`lumiere` repo (`make build`).

## Maintenance — the formula is bumped automatically

`Formula/lumiere.rb` pins the release's darwin zip **asset id + sha256**, both of
which change every release. Do **not** hand-edit them. They are rewritten by
`lumiere`'s release tooling:

- `scripts/release-darwin.sh <version>` (run on the Mac that holds the signing
  cert) builds, signs, notarizes, and uploads the macOS zip, then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the
  published release, rewrites the three release-specific lines, and opens a PR
  here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>`
from the `lumiere` checkout (`--dry-run` to preview).

## sleipnir

The [`sleipnir`](https://github.com/21StarkCom/sleipnir) CLI — drives dedicated,
persistent Chrome profiles for ad-hoc agent tasks (per-task user-agent, headless
or headed, plus a suite of capabilities).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/sleipnir
```

The token is required: this repo and the `sleipnir` releases are **private**, and
the formula's `SleipnirGitHubPrivateReleaseStrategy` fetches the release asset by
its GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). sleipnir drives system Chrome and a Swift
AX/CGEvent helper, so there is no Linux build. sleipnir has **no build step** —
Node 26 runs its TypeScript directly — so the release zip is the runnable tree
(source + a vendored prod `node_modules`) plus the Developer-ID-signed + notarized
Swift `mac-helper`. The formula installs the tree into `libexec` and wraps `slp` /
`sleipnir` over Homebrew's `node` (a formula dependency).

## Maintenance — the sleipnir formula is bumped automatically

`Formula/sleipnir.rb` pins the release's darwin zip **asset id + sha256**, both of
which change every release. Do **not** hand-edit them. They are rewritten by
`sleipnir`'s release tooling:

- `scripts/release-darwin.sh <version>` (run on the Mac that holds the signing
  cert) builds the Swift helper, assembles + signs + notarizes the macOS zip,
  creates the release, uploads the asset, then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the
  published release, rewrites the three release-specific lines, and opens a PR
  here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>`
from the `sleipnir` checkout (`--dry-run` to preview).

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
the cask's `MimirPrivateReleaseStrategy` fetches the release asset by its GitHub API URL with
an `Authorization` header.

**macOS 26 (Tahoe) arm64 only** (Apple Silicon). The release zip is the Developer-ID-signed,
notarized, and **stapled** `Mimir.app`, so Gatekeeper validates it offline. `brew uninstall
--cask mimir` removes the app; `--zap` also trashes its local data (but never the
login-Keychain vault key — that is the app's own Danger Zone → Erase Everything).

## Maintenance — the mimir cask is bumped automatically

`Casks/mimir.rb` pins the release's darwin zip **asset id + sha256** and the **version**, all
of which change every release. Do **not** hand-edit them. They are rewritten by `mimir`'s
release tooling:

- `scripts/release-darwin.sh <version>` (run on the Mac that holds the signing cert) builds +
  signs the app (`make app`), notarizes + staples it, re-zips the stapled bundle, records the
  notarization in the `apple-developer` ledger, uploads the asset onto the hand-cut release,
  then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the published
  release, rewrites the three release-specific lines, and opens a PR here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>` from the
`mimir` checkout (`--dry-run` to preview).

## heimdall

The [`heimdall`](https://github.com/21StarkCom/heimdall) CLI — personal
native-APNs push relay. `heimdall send <title>` fires a Mac banner **and** pushes
to your iPhone / iPad via your own APNs key and app (no third-party push service).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/heimdall
```

The token is required: this repo and the `heimdall` releases are **private**, and
the formula's `HeimdallPrivateReleaseStrategy` fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). The zip is the Developer-ID-signed +
notarized `heimdall` binary. Config (backend URL + send-secret) reads from the
login Keychain (service `heimdall`), or `HEIMDALL_URL` / `HEIMDALL_SEND_SECRET`.

## Maintenance — the heimdall formula is bumped by local Mac scripts

`Formula/heimdall.rb` pins the release's darwin zip **asset id + sha256** — both
change every release, so they are rewritten by the source repo's tooling, never
hand-edited:

- `scripts/release-darwin.sh <version>` (run on the Mac that holds the signing
  cert) builds, Developer-ID-signs, notarizes, and uploads the darwin/arm64 zip,
  then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the
  published release, rewrites the three release-specific lines, and opens a PR here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>` from
the `heimdall` checkout (`--dry-run` to preview). heimdall has no release-please —
cut the tag + GitHub Release first, then run the release script.

## plume

The [`plume`](https://github.com/21StarkCom/plume) pure-Go document toolkit — one
`plume-<format>` driver per format (`plume-xlsx`, `plume-docx`, `plume-pdf`,
`plume-pptx`), each a thin CLI over the format's library package (the library is
the product; these binaries are the drivers).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/plume
```

The token is required: this repo and the `plume` releases are **private**, and
the formula's `PlumePrivateReleaseStrategy` fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon) — matching the rest of this tap. plume is
`CGO_ENABLED=0` pure Go and its `release.yml` genuinely cross-compiles
`{linux,darwin}/{amd64,arm64}`, so a non-Mac (or Intel Mac) can `make build` /
`go install` straight from the `plume` repo; the formula pins the darwin/arm64
tarball only. That build carries Go's linker **ad-hoc** signature (not Developer-ID
notarized), so it runs under Homebrew (which strips the quarantine xattr) but a
raw untar outside Homebrew hits Gatekeeper.

## Maintenance — the plume formula is bumped automatically (by GitHub Actions)

`Formula/plume.rb` pins the release's darwin/arm64 tarball **asset id + sha256**
and **version**, all of which change every release. Do **not** hand-edit them.
Unlike the local-Mac-script tools above, `plume` builds, publishes, and bumps
entirely from a **GitHub Actions** workflow (`release.yml`) on a semver tag push,
which cross-compiles the four-platform release, publishes it, then runs
`plume/scripts/bump-tap.sh --push`, which:

- reads the darwin/arm64 tarball's asset id + sha256 back from the published
  GitHub Release, rewrites the three release-specific lines, and pushes the bump
  straight to this tap's default branch — **no PR**, the same CI hands-off path
  idun / alfred / tyr use.

The bump job authenticates to this (separate) tap repo through the shared
`HOMEBREW_TAP_TOKEN` secret on the `plume` repo (a fine-grained PAT with
`contents:write` here — a direct push needs no Pull-requests scope); if that
secret is unset the job self-skips and the formula must be bumped by hand. To
open a review PR instead (or re-point at an existing release by hand), run
`scripts/bump-tap.sh <version>` from the `plume` checkout (`--dry-run` to preview,
default path opens a PR).

## brain

The [`brain`](https://github.com/21StarkCom/atlas) CLI — the **Atlas** engine
(`@atlas/cli`): ingest notes, build the retrieval index, query/answer over a
vault, and run the review/housekeep surfaces.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/brain
```

The token is required: this repo and the `atlas` releases are **private**, and
the formula's `BrainPrivateReleaseStrategy` fetches the release asset by its
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

## Maintenance — the brain formula is bumped automatically

`Formula/brain.rb` pins the release's darwin/arm64 zip **asset id + sha256** and
**version**, all of which change every release. Do **not** hand-edit them. They
are rewritten by `atlas`'s release tooling, run on a Mac holding the signing
cert:

- `scripts/release-darwin.sh cli-vX.Y.Z` — `pnpm -r build`, `pnpm deploy`, prune,
  Developer-ID sign, zip, upload onto the GitHub Release, then calls…
- `scripts/bump-tap.sh cli-vX.Y.Z`, which reads the asset id + sha256 back from
  the published release and opens the bump PR here (`--dry-run` to preview,
  `--no-pr` to edit a local clone). Re-point at an existing release by running
  `bump-tap.sh cli-vX.Y.Z` on its own.

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

## Maintenance — the atlas cask is bumped by local Mac scripts

`Casks/atlas.rb` pins the release's **asset id + sha256** and **version**, all of
which change every release. Do **not** hand-edit them. The desktop app is built,
signed, and notarized on a Mac holding the cert via `atlas`'s
`apps/desktop/scripts/{sign-app.mjs --notarize, release.mjs --publish}`, which
publishes the notarized `Atlas-<version>.zip` onto a `desktop-v*` GitHub Release.
Re-point the cask at a release by rewriting those three lines against the
published asset.
