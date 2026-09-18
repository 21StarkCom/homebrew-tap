# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Private Homebrew tap for the 21Stark fleet (`21StarkCom/homebrew-tap`, referenced by brew as `21StarkCom/tap`). Each entry installs a **code-signed macOS arm64** build pulled from a **private** GitHub Release asset — signing runs from ad-hoc (idun/hermod) through Developer-ID (most) to Developer-ID **+ notarized** (mimir, brain, atlas). **CLIs are formulae in `Formula/`; GUI `.app`s (Mímir, Atlas) are casks in `Casks/`** (`brew install --cask 21StarkCom/tap/{mimir,atlas}`) — a `.app` belongs in a cask, not a formula. The mimir cask's zip is the notarized + **stapled** `Mimir.app` with the nested `mimir` CLI symlinked onto PATH by a `binary` stanza; the atlas cask ships `Atlas.app` with **no `binary` stanza** (its bundled CLI closure must not shadow the `brain` formula). Most formulae are `bun build --compile` single binaries, but **`brain` is a node-ESM `pnpm deploy` tree** installed into `libexec` and run under the keg `node` — a distinct pattern (see "Adding a formula").

## Big picture

Two facts drive everything here:

1. **Private-release download strategy.** The repo *and* the release assets are private, so a plain `url` won't fetch. Each formula defines a `CurlDownloadStrategy` subclass whose `_fetch` adds `Authorization: token $HOMEBREW_GITHUB_API_TOKEN` and hits the **GitHub API asset URL** (`api.github.com/repos/.../releases/assets/<id>`), not the browser download URL. It raises if the token is missing. Kept deliberately minimal — no Homebrew-internal GitHub API helpers, since those change between brew versions.

2. **This tap is a passive publish target — it does not build anything.** Three lines per formula/cask are release-specific and change every release: `version`, the numeric **asset id** inside the `url`, and `sha256`. They are **rewritten by tooling in the source repo** (`lumiere` / `tyr` / `sleipnir` / `mimir`, each with `scripts/release-darwin.sh` + `scripts/bump-tap.sh`; `hermod`'s pair lives under `ts/scripts/`), which opens a PR here. Do **not** hand-edit them. Release flow (run from the source-repo checkout, on the Mac holding the signing cert): `scripts/release-darwin.sh <version>` builds/signs/notarizes/uploads, then calls `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the published release and opens the bump PR. Re-point at an existing release with `scripts/bump-tap.sh <version>` (`--dry-run` to preview). Auto-bump *commits* land as `chore: bump <formula> to v<x> (asset <id>)`; the matching *PR title* is the same subject without the `(asset <id>)` suffix. Hermod's optional `--ticket STARK-<n>` scopes both to `chore(STARK-<n>): …`, and its squash subject is drafted from that PR title (see below). The bumper edits those three fields with anchored per-field regexes, not by line position, so reordering `url`/`version`/`sha256` in a formula (e.g. a RuboCop `ComponentsOrder` fix) never breaks a future auto-bump.

**Strategy class names must be unique per entry.** Every formula *and* cask ships the same download-strategy pattern, and Ruby classes share one namespace across the tap (casks included) — a collision silently makes one entry use another's class. Each names theirs `<Name>PrivateReleaseStrategy` (`TyrPrivateReleaseStrategy`, `LumierePrivateReleaseStrategy`, `SleipnirGitHubPrivateReleaseStrategy`, `MimirPrivateReleaseStrategy`, `BrainPrivateReleaseStrategy`, `AtlasPrivateReleaseStrategy`); **new formulae and casks do the same.** Self-contained per-entry classes are deliberate — a shared `require_relative`'d strategy file is more fragile in a tap than the tiny duplication it removes.

Platform: `depends_on :macos` + `depends_on arch: :arm64`. Apple Silicon only; Linux builds from source in the tool's own repo.

## Commands

```sh
# Install (consumer) — token needs read access to 21StarkCom private repos
export HOMEBREW_GITHUB_API_TOKEN=<github PAT>
brew install 21StarkCom/tap/tyr

# Lint / audit a formula edit (run from repo root)
brew style Formula/tyr.rb
brew audit --strict 21StarkCom/tap/tyr        # add --online to check the URL/homepage

# Same for the cask (a GUI app)
brew style Casks/mimir.rb
brew audit --cask 21StarkCom/tap/mimir

# Exercise the real install + the formula's `test do` block (needs the token)
brew reinstall 21StarkCom/tap/tyr
brew test 21StarkCom/tap/tyr
```

The tap is already registered locally, but the registration is a **separate git clone** at `/opt/homebrew/Library/Taps/21starkcom/homebrew-tap`, not a symlink to this checkout. `brew style Formula/tyr.rb` accepts an explicit path and checks this working tree. Modern `brew audit` rejects path arguments; `brew audit --strict 21StarkCom/tap/<name>` reads the registered clone instead. Check syntax and style before merging, then verify that clone is clean, fast-forward it to the merged formula, and run the named audit. Confirm the registered formula matches the reviewed version, asset ID, and checksum before trusting the result. Never discard another process's changes in that shared clone. `brew test` runs only the `test do` block, so keep those assertions **version-agnostic**: assert `version.to_s` against the tool's `version` output rather than a hardcoded string (see `STARK-908`, commit `590f38a`).

Use `idun gh pr-open` and `idun gh pr-merge` for the PR gates. Every title must carry its ticket: `chore(STARK-<n>): bump <formula> to v<x>`. If a source bumper cannot produce that title — today every bumper but hermod's — run its `--no-pr` mode in a dedicated checkout, then open the generated change with `idun`. Hermod's is the exception: it takes an optional `--ticket STARK-<n>` (`release-darwin.sh` forwards it) and titles its own PR `chore(STARK-<n>): bump hermod to v<x>`. Pass it — without it the PR title, and so the squash subject, carries no scope. If you forget, either retitle the open PR (`gh pr edit <n> --title "chore(STARK-<n>): bump hermod to v<x>"`) — `idun gh pr-merge` reads the live title, so that retitle is the whole fix — or re-run the bumper with `--ticket`: since hermod v0.18.1 a re-run reuses `bump/hermod-<version>`, fast-forwards the branch the first run pushed, and `gh pr edit`s the open PR's title and body instead of colliding with them (hermod STARK-5069). Bumper retries require a tap checkout with no tracked edits — the bumper refuses to open or update a PR otherwise. A malformed `--ticket` value is refused up front; omitting the flag is not. That PR is opened with plain `gh pr create`, so `idun gh pr-open`'s checks never run on it — review the formula diff, asset id and checksum yourself before merging. Run native Codex xhigh review, fix findings, and rebase before squash-merging. The scanner may flag a formula's public 64-hex checksum as high-entropy; verify it against the downloaded release bytes before using `--allow-secret-commit` on `idun gh pr-open`. This repo's `.stark-gh.json` already provides the audited merge waivers `allowSecretCommit` and `allowSecretToLlm`; `idun gh pr-merge` reads them without extra flags.

Hermod's bumper previews `--dry-run` changes without editing the checkout. Its `--no-pr` mode requires `--tap-dir` so the generated formula remains available for review. Verify exactly one matching ZIP and checksum sidecar, and hash the downloaded ZIP yourself before trusting the formula pin.

## Adding a formula (or cask)

**CLI → formula.** Copy an existing formula, then: rename the strategy class to `<Name>PrivateReleaseStrategy`, point `homepage`/`url` at the new private repo, and update `install` for the shipped binaries (`bin.install "tyr", "tyr-serve"` names them explicitly; `bin.install Dir["lumiere-*"]` globs). Leave `version`/asset-id/`sha256` to the source repo's bump tooling. Update `README.md` in the same PR.

**Node-ESM CLI → formula** (`Formula/brain.rb` is the model). Not a single compiled binary: the release zip is a **`pnpm deploy` tree** (`dist/` + a vendored `node_modules` with the workspace deps and the signed native modules) plus any runtime data the CLI reads from disk. `install` does `libexec.install Dir["*"]` (the whole tree, layout intact — relative pnpm symlinks survive `ditto`) and writes a `bin` wrapper that runs the entry under a runtime dep (`depends_on "node"`; `exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"`). brain also `export`s `ATLAS_ROOT="#{libexec}"` so it finds its bundled command registry without walk-up. `test do` asserts `version.to_s` against the tool's own `version` output. Same three release-specific lines left to the bump tooling.

**GUI `.app` → cask** (`Casks/mimir.rb` is the model). Same private-release strategy class at the top of the file; then `app "X.app"` places the bundle in `/Applications`, `binary "#{appdir}/X.app/Contents/Resources/bin/<cli>"` symlinks a nested CLI onto PATH (a symlink, never a copy — the CLI resolves its own path to find the app it pins), `depends_on macos:` pins the build's deployment target, and `uninstall quit:` closes the running app on upgrade. Ideally the release zip contains the notarized + **stapled** `.app` at its root (mimir does). The atlas cask is the exception: its `Atlas.app` is notarized but **not stapled** (a gap in the desktop `release.mjs` — it zips before stapling), which still installs fine because `brew install --cask` strips the quarantine xattr, so Gatekeeper never gates it offline. Same three release-specific lines (`version`, asset id, `sha256`) — left to the source repo's bump tooling.
