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

## cmux-client

The [`cmux-client`](https://github.com/21StarkCom/cmux-client) CLI + engine for
the [cmux](https://github.com/manaflow-ai/cmux) control API — one bun/TypeScript
binary that spawns/splits tabs, drives the per-workspace todo checklist (a one-
shot command group plus an interactive TUI), and finds orphaned surface
processes.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/cmux-client
```

The token is required: this repo and the `cmux-client` releases are **private**,
and the formula's `CmuxClientPrivateReleaseStrategy` fetches the release asset by
its GitHub API URL with an `Authorization` header.

**macOS arm64 only** (Apple Silicon). Same ad-hoc signature story as `idun`: the
release zip is a `bun build --compile` binary carrying bun's linker-signed
**ad-hoc** signature — it runs under Homebrew (which strips the quarantine
xattr) but is **not** Developer-ID notarized, so a raw unzip outside Homebrew
hits Gatekeeper. `cmux-client` reaches its cmux app over the inherited
`CMUX_SOCKET_PATH`, so run it from inside a cmux surface (or set the socket env
yourself).

## Maintenance — the cmux-client formula is bumped automatically

`Formula/cmux-client.rb` pins the release's darwin zip **asset id + sha256**,
both of which change every release. Do **not** hand-edit them. They are
rewritten by `cmux-client`'s release tooling:

- `scripts/release-darwin.sh <version>` (run on a Mac) builds, ad-hoc signs,
  zips, and uploads the macOS zip onto the GitHub Release, then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from
  the published release, rewrites the three release-specific lines, and opens a
  PR here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>`
from the `cmux-client` checkout (`--dry-run` to preview).

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
