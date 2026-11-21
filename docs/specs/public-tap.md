# Public entries of `21StarkCom/tap`

Anyone can install the public entries of this tap with no GitHub login:

```sh
brew tap 21StarkCom/tap
brew install 21StarkCom/tap/tyr
```

`21StarkCom/homebrew-tap` is public. Each public entry downloads its asset from
a public release of this repo. Every other entry downloads a private release
asset of its source repo, with a GitHub token, as before. The source repos stay
private. STARK-19553 holds the work.

## Why

- GitHub keeps the release assets of a private repo private. A download with no
  token answers `404`, so the assets that anyone may install must live in a
  public repo.
- The common practice for a closed-source CLI is a public tap whose recipes
  download from a public URL with no token.
- One tap gives one install name, `21StarkCom/tap/<entry>`, to the operator and
  to everyone else. STARK-19531 first built a second tap, `21StarkCom/public`,
  with copies made by `scripts/mirror.sh`. The operator approved this one-tap
  design on 2026-11-21 in its place, and with it the change of this repo to
  public.

## Decisions

| # | Decision |
|---|---|
| P1 | `21StarkCom/homebrew-tap` is public, with issues, wiki and projects off (`repos/repos.tf` in `21StarkCom/21stark`). The source repos stay private. |
| P2 | An entry is public when its `url` is `https://github.com/21StarkCom/homebrew-tap/releases/download/<entry>-v<version>/<asset>`. It holds one line `# Source release repo: <owner>/<repo>`, which names the repo whose release the bumper reads. Its `homepage` is this repo. It holds no token code: no `headers:`, no token lookup and check, no cask download adapter, and no caveat that asks for GitHub access. |
| P3 | An entry goes public only when its asset holds no readable JS. On 2026-11-21 the public entries are the twelve Go formulae (`bragi`, `frigg`, `frigg-linux`, `heimdall`, `lumiere`, `plume`, `sonar`, `sonar-linux`, `stark-statusline`, `tyr`, `urd`, `urd-linux`), `mimir`, whose binary embeds its web UI as minified JS, and `goldfinger`, whose Safari extension holds a readable `background.js` that the operator let go by name. The entries in `bun build --compile` binaries, node ESM trees, Bun bundles and Electron apps stay private. |
| P4 | `scripts/bump.sh` publishes a public entry's asset before it pins it. It reads the source release as for any entry, runs `scripts/source-check.pl` on the asset, and makes the release `<entry>-v<version>` of this repo: a draft, the upload read back against the hash, then published. A release that holds the name with that hash is reused. Other bytes under the name stop the run: a public asset is never replaced. |
| P5 | `scripts/source-check.pl` holds the rules of the source check (spec D12 of `docs/specs/getevinced-mirror.md`). `mirror.sh` runs it on an unpacked tree; `bump.sh` runs it on a `.zip` or `.tar.gz` in memory, with core Perl modules only, since its callers may lack `unzip`. |
| P6 | The source repos' release steps do not change. They run `bump.sh` from `main`, so they get the public mode with it. Their token already pushes branches here, so it can make releases here too. |
| P7 | The GetEvinced copy of a public entry keeps its `url` and copies no asset: the public release serves GetEvinced's members too. |
| P8 | `21StarkCom/homebrew-public` is archived. Its last commit holds `tap_migrations.json`, which sends each of its entries to `21StarkCom/tap`, and no entries. The GitHub App `21stark-public-tap` stays, with no write left: it is installed on that archived repo only. |

## The bumper

`scripts/bump.sh <entry> <tag>` reads the entry. A public entry gives its
source repo from its source line, and the run then works as for any entry, with
these steps added:

1. After it downloads and hashes the source asset, it runs
   `perl scripts/source-check.pl --entry <entry file> --archive <asset>`. A line
   of output fails the run, and so does an asset the check cannot read.
2. It computes the public URL from the entry, the version and the asset's name.
3. Before it edits the entry (a `--no-pr` run or a PR run), it publishes the
   release. A run that finds the entry already pinned checks the release too,
   and publishes it when it is missing. `--dry-run` only says what it would
   publish.
4. The PR body names the release. `bumper_shape` accepts the public `url` line,
   so `--merge` and a rerun treat the PR as the bumper's own.

A failed run can leave a draft release. A draft has no tag, so the next run
makes a new one, and the old draft stays invisible to everyone but the repo's
writers.

## CI

- `scripts/verify-auth.rb` fetches each public entry with no token and gh's
  login hidden, and runs `brew info --json=v2` the same way. It fails a public
  entry that holds token code. Each private entry keeps its missing-token
  checks.
- The gh-login step of `formulae.yml` fetches two private entries, `muninn` and
  the `idavoll` cask: a public entry would prove nothing there.
- `scripts/test-bump.sh` covers each step above, under bash 3.2 too, with zip
  fixtures that `IO::Compress::Zip` makes.
- `scripts/test-mirror.sh` checks that `source-check.pl --archive` refuses the
  same files as the tree check, and covers the GetEvinced copy of a public entry.

## Live proof

1. With the tap public, `scripts/bump.sh <entry> <tag> --no-pr` publishes each
   public entry's release from its current pin.
2. With no credential: `curl` of a public URL answers `200`, and its sha256 is
   the pin; the API URL of a private asset answers `404`.
3. On a Mac with no GitHub token, `brew install 21StarkCom/tap/tyr` and
   `brew test 21StarkCom/tap/tyr` pass.
4. The first `mirror.yml` run after the merge passes.

## Risks

- **Reach:** anyone can download each public asset and read its binary. P3
  keeps readable JS out, but a determined reader can still read machine code.
- **A wrong public entry is public for good.** Look for readable JS by hand, and
  run `scripts/mirror.sh --check <entry> <archive>`, before a PR converts it.
- **History:** the repo's commits, PR text and Actions logs are public. STARK-19531
  scanned them for secrets before the change and found none.
- **Readable private recipes:** anyone can read the 20 private entries and their
  source repo names, but cannot download their assets.
- **A caller's token:** each source repo's release token can now make releases
  here. A leaked one could publish a release, but a bump PR still needs review.

## Not built

- Pruning of old public releases and of drafts left by failed runs.
- A switch that makes an entry public with no hand edit: conversion is one PR.
- Bottles: each entry still downloads its release asset.
