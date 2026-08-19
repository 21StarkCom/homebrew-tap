# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Private Homebrew tap for the 21Stark fleet (`21StarkCom/homebrew-tap`, referenced by brew as `21StarkCom/tap`). Each formula in `Formula/` installs a **signed + notarized macOS arm64** build pulled from a **private** GitHub Release asset.

## Big picture

Two facts drive everything here:

1. **Private-release download strategy.** The repo *and* the release assets are private, so a plain `url` won't fetch. Each formula defines a `CurlDownloadStrategy` subclass whose `_fetch` adds `Authorization: token $HOMEBREW_GITHUB_API_TOKEN` and hits the **GitHub API asset URL** (`api.github.com/repos/.../releases/assets/<id>`), not the browser download URL. It raises if the token is missing. Kept deliberately minimal — no Homebrew-internal GitHub API helpers, since those change between brew versions.

2. **This tap is a passive publish target — it does not build anything.** Three lines per formula are release-specific and change every release: `version`, the numeric **asset id** inside the `url`, and `sha256`. They are **rewritten by tooling in the source repo** (`lumiere` / `tyr`), which opens a PR here. Do **not** hand-edit them. Release flow (run from the source-repo checkout, on the Mac holding the signing cert): `scripts/release-darwin.sh <version>` builds/signs/notarizes/uploads, then calls `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the published release and opens the bump PR. Re-point at an existing release with `scripts/bump-tap.sh <version>` (`--dry-run` to preview). Auto-bump PRs land as `chore: bump <formula> to v<x> (asset <id>)`.

**Strategy class names must be unique per formula.** All formulae ship the same download-strategy pattern, and Ruby classes share one namespace across the tap — a collision silently makes one formula use another's class. Both formulae name theirs `<Name>PrivateReleaseStrategy` (`TyrPrivateReleaseStrategy`, `LumierePrivateReleaseStrategy`); **new formulae do the same.** Self-contained per-formula classes are deliberate — a shared `require_relative`'d strategy file is more fragile in a tap than the tiny duplication it removes.

Platform: `depends_on :macos` + `depends_on arch: :arm64`. Apple Silicon only; Linux builds from source in the tool's own repo.

## Commands

```sh
# Install (consumer) — token needs read access to 21StarkCom private repos
export HOMEBREW_GITHUB_API_TOKEN=<github PAT>
brew install 21StarkCom/tap/tyr

# Lint / audit a formula edit (run from repo root)
brew style Formula/tyr.rb
brew audit --strict 21StarkCom/tap/tyr        # add --online to check the URL/homepage

# Exercise the real install + the formula's `test do` block (needs the token)
brew reinstall 21StarkCom/tap/tyr
brew test 21StarkCom/tap/tyr
```

The tap is already registered locally; edits to `Formula/*.rb` in this checkout are what `brew` resolves. `brew test` runs only the `test do` block, so keep those assertions **version-agnostic** — assert `version.to_s` against the tool's `version` output rather than a hardcoded string (see `STARK-908`, commit `590f38a`).

## Adding a formula

Copy an existing formula, then: rename the strategy class to `<Name>PrivateReleaseStrategy`, point `homepage`/`url` at the new private repo, and update `install` for the shipped binaries (`bin.install "tyr", "tyr-serve"` names them explicitly; `bin.install Dir["lumiere-*"]` globs). Leave `version`/asset-id/`sha256` to the source repo's bump tooling. Update `README.md` in the same PR.
