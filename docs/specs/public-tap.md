# Public entries of `21StarkCom/tap`

Anyone can install each entry of this tap with no GitHub login:

```sh
brew tap 21StarkCom/tap
brew install 21StarkCom/tap/tyr
```

`21StarkCom/homebrew-tap` is public. Each entry downloads its asset from a
public release of this repo. The source repos stay private. STARK-19553 made
14 entries public, and STARK-19636 made the other 20 public.

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
| P3 | Every entry is public: the operator decided on 2026-11-21, "all can be public". Readable JS and shell source may go public. A secret may not: before an asset goes public, `gitleaks dir` scans it unpacked, with the strings of each Mach-O or ELF file. An entry whose asset holds a live secret stays private, in the private shape that the bumper and `verify-auth.rb` still support. A new entry starts public. |
| P4 | `scripts/bump.sh` publishes a public entry's asset before it pins it. It reads the source release as for any entry, runs `scripts/source-check.pl` on the asset, and makes the release `<entry>-v<version>` of this repo: a draft, the upload read back against the hash, then published. A release that holds the name with that hash is reused. Other bytes under the name stop the run: a public asset is never replaced. |
| P5 | `scripts/source-check.pl` holds the rules of the source check (spec D12 of `docs/specs/getevinced-mirror.md`). `mirror.sh` runs it on an unpacked tree; `bump.sh` runs it on a `.zip` or `.tar.gz` in memory, with core Perl modules only, since its callers may lack `unzip`, and on a `.pkg` through `bsdtar`, as `mirror.sh` reads one. |
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
  entry that holds token code. Its missing-token checks of a private entry
  stay, for a future one.
- `formulae.yml` has no gh-login step: with no private entry, it would prove
  nothing. `scripts/verify-download.rb` checks the preflight and a partial
  resume of the public `muxctl` with no token.
- `scripts/test-bump.sh` covers each step above, under bash 3.2 too, with zip
  fixtures that `IO::Compress::Zip` makes, and a `.pkg` that `bsdtar` makes.
  Alpine's `bsdtar` cannot write a `.pkg`, so the bash 3.2 job skips that test.
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

- **Reach:** anyone can download each public asset and read it. The node ESM
  trees, Bun bundles and Electron apps hold readable JS, and `muninn` is its
  bash source tree. The operator accepted this.
- **A secret in an asset is public for good.** Scan each asset for secrets
  before its first publish (P3). STARK-19636 scanned the 20 assets it made
  public and found only false positives: public keys, PEM header strings and
  minified code.
- **History:** the repo's commits, PR text and Actions logs are public. STARK-19531
  scanned them for secrets before the change and found none.
- **A caller's token:** each source repo's release token can now make releases
  here. A leaked one could publish a release, but a bump PR still needs review.

## Not built

- Pruning of old public releases and of drafts left by failed runs.
- A secret scan in the bumper: the scan before a first publish is a hand step.
- Bottles: each entry still downloads its release asset.
