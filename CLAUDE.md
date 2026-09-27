# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Private Homebrew tap for the 21Stark fleet (`21StarkCom/homebrew-tap`, referenced by brew as `21StarkCom/tap`). Each entry installs a **code-signed macOS arm64** build pulled from a **private** GitHub Release asset — signing runs from ad-hoc (idun/hermod) through Developer-ID (most) to Developer-ID **+ notarized** (mimir, brain, atlas, lumiere, goldfinger). **CLIs are formulae in `Formula/`; GUI `.app`s (Mímir, Atlas, Goldfinger) are casks in `Casks/`** (`brew install --cask 21StarkCom/tap/{mimir,atlas,goldfinger}`) — a `.app` belongs in a cask, not a formula. The mimir cask's zip is the notarized + **stapled** `Mimir.app` with the nested `mimir` CLI symlinked onto PATH by a `binary` stanza; the goldfinger cask's is the stapled `Goldfinger.app`, whose one executable (daemon and CLI) its `binary` stanza symlinks onto PATH; the atlas cask ships `Atlas.app` with **no `binary` stanza** (its bundled CLI closure must not shadow the `brain` formula). Most formulae are `bun build --compile` single binaries, but **`brain` is a node-ESM `pnpm deploy` tree** installed into `libexec` and run under the keg `node` — a distinct pattern (see "Adding a formula").

## Big picture

Two facts drive everything here:

1. **Native authenticated downloads.** Each entry puts `Accept: application/octet-stream` and the stripped `HOMEBREW_GITHUB_API_TOKEN` on its GitHub API asset URL: `headers:` for formulae. Casks retain a small initialization-only adapter that sets the same native download metadata, because cask URL headers are serialized verbatim by `brew info --json`. Homebrew owns preflight, redirects, cache freshness, and partial resume. Never override `_fetch` or issue curl commands in the tap. An absent or whitespace-only token raises `CurlDownloadStrategyError.new(url, guidance)`: during formula evaluation or cask downloader initialization. Formula metadata commands therefore require the token too.

2. **This tap is a passive publish target — it does not build anything.** Three lines per formula/cask are release-specific and change every release: `version`, the numeric **asset id** inside the `url`, and `sha256`. Do **not** hand-edit them. Each source repo's release step calls the bumper (below), which reads the asset id and sha256 back from the published release, rewrites those lines and opens a PR here; `README.md`'s caller table names the release step that calls it for each entry. Bump *commits* land as `chore: bump <entry> to <tag> (asset <id>)`; the matching *PR title* is the same subject without the `(asset <id>)` suffix, `--ticket STARK-<n>` scopes both to `chore(STARK-<n>): …`, and the squash subject is drafted from that PR title. The bumper edits those three fields with anchored per-field regexes, not by line position, so reordering `url`/`version`/`sha256` in a formula (e.g. a RuboCop `ComponentsOrder` fix) never breaks a future auto-bump.

**Keep release fields compatible with the bumper.** Preserve standalone `url "…",`, `version "…"`, and `sha256 "…"` stanzas, each exactly once; the bumper refuses an entry with more or fewer. Auth headers are continuation arguments to the URL. Never move the asset pin into a helper or interpolate the version into it.

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

# Preview a bump (any checkout), and run the bumper's tests (local only: a bare
# remote and a stubbed gh; BUMP_TEST_BASH=/bin/bash runs bump.sh under bash 3.2)
scripts/bump.sh <entry> <tag> --dry-run
scripts/test-bump.sh
```

The tap is already registered locally, but the registration is a **separate git clone** at `/opt/homebrew/Library/Taps/21starkcom/homebrew-tap`, not a symlink to this checkout. `brew style Formula/tyr.rb` accepts an explicit path and checks this working tree. Modern `brew audit` rejects path arguments; `brew audit --strict 21StarkCom/tap/<name>` reads the registered clone instead. Check syntax and style before merging, then verify that clone is clean, fast-forward it to the merged formula, and run the named audit. Confirm the registered formula matches the reviewed version, asset ID, and checksum before trusting the result. Never discard another process's changes in that shared clone. `brew test` runs only the `test do` block, so keep those assertions **version-agnostic**: assert `version.to_s` against the tool's `version` output rather than a hardcoded string (see `STARK-908`, commit `590f38a`).

**The bumper is `scripts/bump.sh`, and its `--help` is the reference** (21stark ADR-0008). A release clones this tap's `main` and runs the script from that clone; to re-point an entry by hand, run it from a clean checkout of this repo at `origin/main` (`--dry-run` previews, `--no-pr` edits the checkout without committing). A source repo not yet migrated to it still runs its own `bump-tap.sh`, and that copy's `--help` is the reference until its migration step lands. Callers run `main` unpinned, so the interface only grows, and a bumper change lands with its tests (`scripts/test-bump.sh`) in the same PR.

Use `idun gh pr-open` and `idun gh pr-merge` for the PR gates. Every title must carry its ticket: `chore(STARK-<n>): bump <entry> to <tag>`. That is this tap's rule, not the bumper's, so pass `--ticket` wherever a ticket exists. The unattended CI mergers (idun, alfred, plume) have none, so their squash subjects stay unscoped. A bumper that cannot produce the scoped title runs in its `--no-pr` mode in a dedicated checkout, and `idun gh pr-open` opens the change. A bump PR already open under an unscoped title needs only a retitle (`gh pr edit <n> --title …`): `idun gh pr-merge` reads the live title. Bumpers open their PRs with plain `gh pr create`, so `idun gh pr-open`'s checks never run on them: review the entry diff, asset id and checksum yourself before merging. Run native Codex xhigh review, fix findings, and rebase before squash-merging. The scanner may flag a formula's public 64-hex checksum as high-entropy; verify it against the downloaded release bytes before using `--allow-secret-commit` on `idun gh pr-open`. This repo's `.stark-gh.json` already provides the audited merge waivers `allowSecretCommit` and `allowSecretToLlm`; `idun gh pr-merge` reads them without extra flags.

## Adding a formula (or cask)

**CLI → formula.** Copy an existing formula, then: keep its native auth headers and token validation, point `homepage`/`url` at the new private repo, and update `install` for the shipped binaries (`bin.install "tyr", "tyr-serve"` names them explicitly; `bin.install Dir["lumiere", "lumiere-*"]` globs — a bare dispatcher name needs its own literal, since `lumiere-*` does not match it). The bumper never creates an entry, so this hand PR pins `version`/asset-id/`sha256` to the first release: once the file exists, `scripts/bump.sh <entry> <tag> --no-pr` fills them in. Every later release bumps them. Update `README.md` in the same PR, caller table included.

**Node-ESM CLI → formula** (`Formula/brain.rb` is the model). Not a single compiled binary: the release zip is a **`pnpm deploy` tree** (`dist/` + a vendored `node_modules` with the workspace deps and the signed native modules) plus any runtime data the CLI reads from disk. `install` does `libexec.install Dir["*"]` (the whole tree, layout intact — relative pnpm symlinks survive `ditto`) and writes a `bin` wrapper that runs the entry under a runtime dep (`depends_on "node"`; `exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"`). brain also `export`s `ATLAS_ROOT="#{libexec}"` so it finds its bundled command registry without walk-up. `test do` asserts `version.to_s` against the tool's own `version` output. Same three release-specific lines left to the bump tooling.

**Bun source-tree CLI → formula** (`Formula/sleipnir.rb` and `Formula/lucius.rb` are the models). No build step at all: the release zip is the runnable TypeScript tree plus a vendored prod `node_modules`, at the zip's top level. `install` does `libexec.install Dir["*"]` (so keep the zip free of top-level dotfiles — `Dir["*"]` skips them) and writes a `bin` wrapper over `depends_on "bun"`: `exec "#{formula_opt_bin("bun")}/bun" "#{libexec}/bin/<entry>.ts" "$@"` (lucius). sleipnir's tree is a workspace since 0.11.0, so it writes one wrapper per command over `#{libexec}/apps/<app>/bin/<entry>.mjs` (`slp`/`sleipnir` → `apps/sleipnir`, `huginn` → `apps/huginn`, `sleipnir-mcp` → `apps/mcp`, the MCP server an agent client starts from its own working directory); its bumper never rewrites them, so a launcher move is a hand edit in that release's tap PR. A bare `sleipnir` resolves to homebrew/cask's browser, so name the formula `21StarkCom/tap/sleipnir` in every `brew` command. Add `--no-env-file --config=/dev/null` when the CLI must not inherit the caller's cwd `.env` or `bunfig.toml` preloads (lucius and sleipnir do; keep the matching `test do` assertion). Homebrew cannot version-constrain a formula dependency, so a Bun floor enforced at runtime (lucius: `>=1.4.2`) is invisible to `brew install` — CI must `brew update` before installing, or it pours a stale bottle and only `brew test` catches it. Same three release-specific lines left to the bump tooling.

**GUI `.app` → cask** (`Casks/mimir.rb` is the model). Keep a uniquely named initialization-only adapter like `MimirPrivateReleaseStrategy` to set native `@meta[:headers]` without exposing credentials in cask JSON; then `app "X.app"` places the bundle in `/Applications`, `binary "#{appdir}/X.app/Contents/Resources/bin/<cli>"` symlinks a nested CLI onto PATH (a symlink, never a copy — the CLI resolves its own path to find the app it pins), `depends_on macos:` pins the build's deployment target, and `uninstall quit:` closes the running app on upgrade. Ideally the release zip contains the notarized + **stapled** `.app` at its root (mimir does). The atlas cask is the exception: its `Atlas.app` is notarized but **not stapled** (a gap in the desktop `release.mjs` — it zips before stapling), which still installs fine because `brew install --cask` strips the quarantine xattr, so Gatekeeper never gates it offline. Same three release-specific lines (`version`, asset id, `sha256`) — left to the source repo's bump tooling.

## Automated verification

`.github/workflows/bump.yml` runs `scripts/test-bump.sh` on ubuntu and macOS (macOS under `/bin/bash` 3.2) for every PR, and `bump.sh --merge` waits for it along with the other two. Its test fails if the bumper's `GATE_WORKFLOWS` differs from the workflows here that trigger on `pull_request`, or if any of them filters that trigger: keep every such trigger unfiltered, and add a new one to `GATE_WORKFLOWS` in the same PR. `brew style … scripts` lints `scripts/*.sh` too, with every optional shellcheck check and Homebrew's `shfmt` layout (`brew style --fix scripts/bump.sh` applies it). Its layout pass misreads a line inside a string or heredoc that starts with `if`, so keep embedded jq, Ruby and stub code free of those.

`.github/workflows/formulae.yml` styles all entries, checks missing/blank token errors, and audits, installs, and tests every formula on macOS arm64. It uses the repository Actions secret `HOMEBREW_RELEASE_READ_TOKEN`, which must have contents-read access to the release repositories. Mimir remains the source of the credential; GitHub stores its encrypted CI copy. It fails if access is unavailable. The workflow also checks hermod preflight metadata and a seeded partial download against the pinned checksum. `scripts/verify-download.rb` must run with a dedicated `HOMEBREW_CACHE`, because it replaces its cached hermod archive with a partial to verify resume. `scripts/verify-auth.rb` uses only synthetic/missing credentials.
