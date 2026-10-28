# Mirror this tap to `GetEvinced/homebrew-tap`

Every entry of this tap (`21StarkCom/tap`) but five also lives in the Evinced
tap, `GetEvinced/homebrew-tap` (`GetEvinced/tap`), with its release asset copied
into GetEvinced. A job in this repo keeps the copy in step after each push to
`main`, with no hand work. An Evinced engineer with read access to the
GetEvinced tap installs those entries with `brew install GetEvinced/tap/<entry>`
and needs no access to 21StarkCom. The five that stay here hold the operator's
source or readable JS (D11).

## Why

- `21StarkCom` has 16 members and `GetEvinced` has 92 (counted on
  2026-10-28). Each entry here downloads a private 21StarkCom release asset,
  so about 76 Evinced engineers cannot install the fleet today.
- The GetEvinced organization gives every member `write` on its repos by
  default, so every member can read the GetEvinced tap and its releases.
- The operator asked for a full replica: whatever this tap holds, the
  GetEvinced tap holds too.

## Today

- `GetEvinced/homebrew-tap` is private. It holds two formulae, `aac` and
  `evinced`, that build from source. The release workflows of
  `GetEvinced/infra-alerts` and `GetEvinced/evinced-cli` push them to `main`
  with one plain `git push` and no retry.
- A ruleset, `main: release-bot-only direct push` (id `17658502`), blocks
  every update, deletion and force push of `main` except by its one bypass
  actor, the `evinced-infra-cloud` GitHub App (app id `2877550`). It guards
  no other branch and no tag. That App has `administration: write` and
  `contents: write` on every GetEvinced repo.
- The GetEvinced tap has no releases, no tags, and no Actions secrets or
  variables. Immutable releases are off.
- This tap holds 19 formulae and 3 casks. Each one pins one asset by its API
  URL (`https://api.github.com/repos/21StarkCom/<repo>/releases/assets/<id>`),
  its `version` and its `sha256`. Each starts with
  `# frozen_string_literal: true`.
- Each source asset reports its SHA-256 in the API (`digest`), and it equals
  the `sha256` the entry pins. The 22 assets total 2.47 GB. The largest are
  Atlas (492 MB), `frigg-linux` (425 MB) and `frigg` (416 MB).
- Entries name this tap in their text: `librarian` has
  `depends_on "21starkcom/tap/brain"`, and the `sleipnir`, `mimir` and
  `goldfinger` texts tell the user to run `brew … 21StarkCom/tap/<entry>`.
  The three casks say that installing needs "read access to 21StarkCom
  private repos".
- Releases here are frequent: `idun` shipped 10 releases between 2026-10-26
  and 2026-10-28.

## Decisions

| # | Decision |
|---|---|
| D1 | The replica copies each asset into GetEvinced. Its entries download from GetEvinced, never from 21StarkCom. The operator picked this on 2026-10-28. |
| D2 | This repo runs the copy, on each push to `main`. The GetEvinced tap runs nothing. The operator picked this on 2026-10-28. |
| D3 | A new GitHub App, `21stark-tap-mirror`, does the GetEvinced writes. GetEvinced owns it, it has `contents: write` and `metadata: read` only, and it is installed on `GetEvinced/homebrew-tap` only. The operator picked this on 2026-10-28. |
| D4 | The App becomes a second bypass actor of ruleset `17658502`. The ruleset and its other actor stay as they are. |
| D5 | The copies live as releases of `GetEvinced/homebrew-tap`, one release per entry and version, tag `<entry>-v<version>`. An asset keeps its source name. When that name holds other bytes in the release, the copy is `<first 12 hex of sha256>-<source name>`. |
| D6 | The job writes only files that hold the mirror marker, and the README block. It reads other files only to refuse a name clash. It never changes `aac`, `evinced` or any other unmarked file. |
| D7 | The job deletes no release and no uploaded asset. It deletes only an incomplete upload that a dead run left (untouched for an hour), which no entry can pin. A younger one may be another run's: the entry fails, and the next run retries. |
| D8 | The job reads 21StarkCom with the existing `HOMEBREW_RELEASE_READ_TOKEN`. It adds no 21StarkCom credential. |
| D9 | The replica copies `Formula/` and `Casks/` only. `scripts/`, the workflows, `CLAUDE.md` and the bumper stay here. |
| D10 | The App key lives in the Actions Environment `getevinced-mirror` of this repo, which only `main` can use. A run on any other ref gets no key. |
| D11 | `atlas`, `brain`, `librarian`, `lucius` and `odinctl` are never copied, and a marked copy of one is deleted. Their assets hold the operator's source (`lucius`: 112 `.ts` files) or readable JS with source maps (the atlas repo's `atlas`, `brain` and `librarian`; `odinctl`). The operator picked them on 2026-10-28, after the first proof run had copied `brain`; that release was deleted by hand. `librarian` also depends on `brain`. `sleipnir` (its TypeScript tree), `agent-seats` (an unminified bundle) and the minified bundles of `idun`, `njord` and `hermod` stay in the mirror: the operator saw what each holds and did not name them. |

## Design

### Parts

| Part | What it does |
|---|---|
| `scripts/mirror.sh` | Makes the GetEvinced tap match this checkout. Idempotent: a second run with no change in between does nothing. |
| `scripts/test-mirror.sh` | Tests `mirror.sh` against a bare git remote and a stubbed `gh`, as `scripts/test-bump.sh` does. |
| `.github/workflows/mirror.yml` | Runs `mirror.sh`, then proves the changed entries download from GetEvinced. |
| `.github/workflows/bump.yml` | Gets one more job that runs `scripts/test-mirror.sh` on each pull request. |
| `CLAUDE.md`, `README.md` | Say that each merge to `main` reaches GetEvinced, and list the copy rules under "Adding a formula". |

`mirror.yml` has no `pull_request` trigger, so it stays out of the bumper's
`GATE_WORKFLOWS` and `scripts/bump.sh` does not change. The tests run in
`bump.yml`, which is already a gate workflow. `formulae.yml` already runs
`brew style … scripts`, so it lints `mirror.sh` and `test-mirror.sh` with
no change.

### `scripts/mirror.sh`

Interface:

```sh
scripts/mirror.sh [--dry-run] [--branch <name>] [--only <entry>]...
```

- `MIRROR_SOURCE_TOKEN` reads the 21StarkCom release assets.
- `MIRROR_TARGET_TOKEN` writes `GetEvinced/homebrew-tap`: its releases and
  the branch.
- `--branch` names the GetEvinced branch to push. The default is `main`.
  When the branch does not exist, the script makes it from `main`. The live
  proof uses a scratch branch.
- `--dry-run` prints the plan and writes nothing.
- `--only` limits steps 3 to 5 to the named entries, for a retry by hand.
  It skips step 6, so a partial run deletes no file.
- The script writes the changed entries to `$GITHUB_OUTPUT` when that file
  is set, as `formulae` and `casks`, one space-separated list each.
- `--help` is its reference, as for `bump.sh`.
- It needs bash 4.4 or later (older bash aborts on an empty array under
  `set -u`), and it checks this at its start. CI runs it on
  `ubuntu-latest`; on a Mac, run it with Homebrew's bash.
- It copies what the checkout holds, so it refuses (exit 2) a checkout with
  uncommitted changes under `Formula/` or `Casks/`, and a push to `main`
  from a HEAD that is not `origin/main`. `--dry-run` and a scratch
  `--branch` skip the second check.
- No token goes into a command line, a URL or `.git/config`. Git gets the
  token from an `http.extraheader` in the environment
  (`GIT_CONFIG_COUNT`), and `gh` gets it from `GH_TOKEN`.

Steps, in this order:

1. Clone the GetEvinced branch.
2. For each `Formula/*.rb` and `Casks/*.rb` in this checkout but the D11
   entries, read the asset URL, `version` and `sha256`. Use the bumper's
   anchored URL pattern (`URL_RE` in `scripts/bump.sh`). An entry fails when
   it has other than one `url`, `version` or `sha256` stanza, when its first
   line is not `# frozen_string_literal: true`, or when a formula and a cask
   share its name.
3. Find the GetEvinced release `<entry>-v<version>`: in the release listing,
   else by its tag (the listing can miss a new one). The entry fails when two
   releases share the tag. Find its asset whose `digest` is
   `sha256:<pinned sha256>` and whose state is `uploaded`.
4. When no such asset exists:
   1. Download the source asset with `MIRROR_SOURCE_TOKEN`.
   2. Compare its SHA-256 with the pinned `sha256`. The entry fails when
      they differ.
   3. Delete each incomplete upload in the release, by D7.
   4. When the release does not exist, create it as a draft: target `main`,
      not marked latest, and a body that names the source repo, the source
      asset id and the SHA-256.
   5. Upload the asset under its D5 name. Delete the download.
   6. Publish the draft.
5. Write the entry's file in the GetEvinced clone. The file is this tap's
   file with the changes in "The copy of an entry" below.
6. Delete each marked GetEvinced file whose entry is no longer in this
   checkout, is a D11 entry, or moved between `Formula/` and `Casks/`.
   Leave the releases of that entry in place.
7. Write the README block (below).
8. Commit all changes in one commit and push it. When the push loses a race
   (`fetch first` or `non-fast-forward`), clone again and do steps 5 to 8
   again, up to three times; step 3 found the uploads already, so they are
   not done again. Any other refusal (a ruleset, a permission) stops the run.
9. Exit non-zero when an entry failed.

Errors:

- An entry that fails is left out of this run: its GetEvinced file stays as
  it was. The other entries go on, and the run exits non-zero at the end.
- An unmarked GetEvinced file with the name of an entry here fails that
  entry.
- An entry that still matches `21starkcom/tap\b`, in any case, after the
  copy rules fails.
- The script uploads all assets before it pushes, and it deletes no
  uploaded asset (D7). So a pushed entry never points at an asset that does
  not exist.

### The copy of an entry

The copy is the source file with these changes, and no others:

1. A marker line and a blank line go after the
   `# frozen_string_literal: true` line and its blank line:
   `# Mirrored from 21StarkCom/homebrew-tap by scripts/mirror.sh. Do not edit: the next run overwrites it.`
2. The asset URL becomes
   `https://api.github.com/repos/GetEvinced/homebrew-tap/releases/assets/<copy id>`.
3. Each match of `21starkcom/tap\b`, in any case, becomes
   `getevinced/tap`, written in the case of the match: `21StarkCom/tap`
   becomes `GetEvinced/tap`, and `21starkcom/tap` becomes `getevinced/tap`.
   This keeps a dependency on another entry, and the caveats that name one
   (`sleipnir`, `mimir`, `goldfinger`), inside the GetEvinced tap.
4. `read access to 21StarkCom private repos` becomes
   `read access to GetEvinced private repos`.

`version`, `sha256`, `homepage`, the token lookup, the sandboxed-worker
skip and each cask's download adapter stay the same. The `homepage` still
names the 21StarkCom source repo, because that repo is the source.
`21StarkCom` and `GetEvinced` have the same length, so no line grows.

A user with both taps loads a cask adapter, for example
`MimirPrivateReleaseStrategy`, from two files. Homebrew's cask loader runs
each cask file with `instance_eval`, so each file gets its own class, and
the two do not clash.

### The README block

The script owns one block of the GetEvinced `README.md`, between
`<!-- BEGIN 21stark-mirror -->` and `<!-- END 21stark-mirror -->`. It adds the
block at the end of the file on the first run. It builds the block from the
marked files in the clone, so the block always agrees with them. The block
holds:

- one line that says the 21StarkCom mirror job writes the block and the
  marked files, and that a change made there is lost at the next run;
- the install commands: `brew tap GetEvinced/tap`,
  `brew trust --tap GetEvinced/tap`, `brew install GetEvinced/tap/<entry>`
  and `brew install --cask GetEvinced/tap/<cask>`;
- the token note: Homebrew's `gh` signed in to an account with read access
  to `GetEvinced/homebrew-tap`, or `HOMEBREW_GITHUB_API_TOKEN`;
- a note that a Mac with both taps must use full names in every `brew`
  command, `brew services` included, for example `GetEvinced/tap/idun`;
- a table with a row per entry: name, kind (formula or cask), version and
  source repo.

The rest of the README stays as the Evinced team wrote it.

### `.github/workflows/mirror.yml`

- Triggers: `push` to `main`, `workflow_dispatch`, and one `schedule` run a
  day. The daily run heals a run that failed.
- Each job has `if: github.ref == 'refs/heads/main'`.
- `concurrency`: one group, `mirror`, with `cancel-in-progress: false`.
  GitHub keeps one pending run, and a newer run replaces it.
- Job `sync`, on `ubuntu-latest`, `environment: getevinced-mirror`,
  `timeout-minutes: 90`:
  1. Check out this repo with `persist-credentials: false`.
  2. Mint an App token with `actions/create-github-app-token`, pinned by
     SHA: `client-id` from `GETEVINCED_TAP_APP_CLIENT_ID`, `owner: GetEvinced`,
     `repositories: homebrew-tap`. The action marks its `app-id` input as
     deprecated (v3.3.0), so the spec uses the Client ID.
  3. Run `scripts/mirror.sh` with `MIRROR_SOURCE_TOKEN` from
     `HOMEBREW_RELEASE_READ_TOKEN` and `MIRROR_TARGET_TOKEN` from the App
     token. Commit as the App's bot user.
- Job `verify`, on `ubuntu-24.04-arm`, `environment: getevinced-mirror`,
  `timeout-minutes: 60`, after `sync`, when `sync` changed an entry. The
  daily run checks every entry:
  1. Put Homebrew on `PATH` and run `brew update`, as `formulae.yml` does.
  2. Mint an App token with `permission-contents: read`.
  3. Check out `GetEvinced/homebrew-tap` with that token and
     `persist-credentials: false`. Link it in as the tap `getevinced/tap`
     and trust it, as `formulae.yml` does for this repo.
  4. Run `brew style` on the changed copies.
  5. Run `brew fetch` on each changed formula and `brew fetch --cask` on
     each changed cask, with the App token as `HOMEBREW_GITHUB_API_TOKEN`.
     Each fetch checks the download against the pinned `sha256`.
  6. For a changed `-linux` formula, check that the download holds a
     Linux x86-64 `<tool>`, as `formulae.yml` does.

A failed run sends GitHub's failure email to the operator: the operator
merges to `main` and wrote the cron line. The spec adds no other alert.

### Setup in GetEvinced and here

1. Create the App `21stark-tap-mirror` in the GetEvinced organization:
   private, no webhook, `contents: write`, `metadata: read`.
2. Install it on `GetEvinced/homebrew-tap` only.
3. Add it to the bypass list of ruleset `17658502`, mode `always`.
4. Make one private key. Store it in Mimir.
5. Make the Environment `getevinced-mirror` in this repo, with a deployment
   branch policy of `main` only.
6. Set its variable `GETEVINCED_TAP_APP_CLIENT_ID` (the App's Client ID)
   and its secret `GETEVINCED_TAP_APP_KEY`.

Steps 1, 2 and 4 need a browser session of a GetEvinced owner. Steps 4 and 6
handle a secret value, so they need the operator's GO.

## Testing

`scripts/test-mirror.sh` uses fixture entries only: `bump.yml` is the gate
of every bump PR, so a change to a real entry must never turn it red. It covers:

- a first run into an empty tap: all entries, releases and the README block;
- the excluded entries (D11): not copied, no `gh` call, a marked copy deleted;
- an entry moved from `Formula/` to `Casks/`: the old copy goes;
- a formula and a cask with one name: both fail;
- a source checkout with uncommitted entries, or not at `origin/main`: exit 2;
- an upload another run has in progress (under an hour old): that entry
  fails, and nothing is deleted;
- a release that the listing misses: the script asks for its tag;
- two releases with one tag: that entry fails;
- a push that loses a race (a commit lands on `main` first): a fresh clone and
  a second push; a push the remote refuses: no retry, exit 1;
- a README whose END line has no newline after it;
- a second run with no change: no upload, no commit;
- a version bump of one entry: one upload, one changed file;
- a reused asset: the release has a matching digest, so no download;
- the same version with new bytes: a `<sha12>-` asset name, and the old
  asset stays;
- a SHA-256 mismatch on download: that entry fails, the others push, and
  the exit is non-zero;
- an incomplete upload left by a failed run: the script deletes and
  replaces it;
- an entry removed here: its marked file goes, its releases stay;
- an unmarked GetEvinced file with an entry's name: that entry fails, the
  file stays;
- `aac.rb` and `evinced.rb` stay byte for byte the same;
- the copy rules on fixtures that have a `depends_on "21starkcom/tap/…"`,
  caveats with `21StarkCom/tap` (with and without a slash after it) and
  `21STARKCOM/tap`, a `21StarkCom/homebrew-tap` that stays, and a cask with
  "21StarkCom private repos";
- `--branch` with a branch that does not exist yet;
- `--only`: other entries and step 6 untouched;
- no token and no base64 git credential in the work directory, the stub's
  argument log or the output;
- `--dry-run`: no write of any kind, with no git identity and no source token.

The live proof and `mirror.yml`'s `verify` job check the copies of the real
entries.

## Live proof

Before merge, after the setup:

1. Run `scripts/mirror.sh --branch mirror-proof` from this checkout with
   the operator's `gh` login as both tokens. This writes real releases,
   which the first run on `main` reuses, and the scratch branch
   `mirror-proof`, which the ruleset does not guard.
2. On the operator's Mac, set `HOMEBREW_NO_AUTO_UPDATE=1` for steps 2 to
   7. Without it, `brew install` runs `brew update`, which checks the
   scratch tap back out to `main`. Tap the scratch tap
   `getevinced/mirror-proof` from `GetEvinced/homebrew-tap`, check out
   `mirror-proof` in it, and trust it.
3. Mint an App token with `permission-contents: read`. It can read
   `GetEvinced/homebrew-tap` only, so it proves that a user needs no
   21StarkCom access. Use it as `HOMEBREW_GITHUB_API_TOKEN` for steps 4
   and 5.
4. Run `brew fetch` of every copied formula and `brew fetch --cask` of every
   copied cask from the scratch tap: 15 formulae and 2 casks (D11 leaves out 5
   of the 22 entries).
5. Run `brew uninstall 21starkcom/tap/tyr`, then
   `brew install getevinced/mirror-proof/tyr` and
   `brew test getevinced/mirror-proof/tyr`.
6. Put the Mac back: `brew uninstall getevinced/mirror-proof/tyr`, then
   `brew install 21starkcom/tap/tyr`.
7. Clean up: untap `getevinced/mirror-proof` while it is still trusted
   (`brew untap` refuses an untrusted tap), then untrust it by its remote.
   Delete the branch `mirror-proof`.

After merge: the push run of `mirror.yml` copies every entry to GetEvinced
`main`. A manual run on `main` then makes no GetEvinced commit. The ticket
gets the run links, the GetEvinced commit, and the output of
`brew tap GetEvinced/tap`, `brew trust --tap GetEvinced/tap` and
`brew fetch GetEvinced/tap/idun` on the operator's Mac. Homebrew 7 loads
no formula from a tap that is not trusted.

## Risks

- **Reach:** every member of GetEvinced, and each outside collaborator of
  its tap, can download every mirrored asset, Mimir and Heimdall included.
  This is the outcome the operator asked for. Some copied assets are still
  readable: `sleipnir` ships its TypeScript tree, and the `bun build
  --compile` binaries embed their JS bundle (`agent-seats` unminified). D11
  lists what the operator left out.
- **A new entry is copied by default.** The exclusion is a list in
  `scripts/mirror.sh`; an entry added to this tap reaches GetEvinced unless
  its PR adds it there.
- **Key leak:** a leaked key of `21stark-tap-mirror` reaches one repo. It can
  still push to that repo's `main`, `aac` and `evinced` included, and the
  Ruby in those files runs on the Macs that install them. D10 keeps the key
  away from every branch but `main`.
- **Push race:** the release workflows of `aac` and `evinced` push once with
  no retry. A mirror push at the same moment can make their push fail. The
  mirror retries; they do not.
- **Lag:** GetEvinced trails this tap by one workflow run. A run that copies
  Atlas or `frigg` takes several minutes, and the first run copies 2.47 GB.
  A run that fails leaves an entry one release behind until the next run.
- **Growth:** D7 keeps every copy, about 1 GB more for each Atlas and
  `frigg` release. A later ticket can prune by age, if the size matters.
- **Immutable releases:** if GetEvinced turns them on, a second asset for a
  published version fails. That entry fails until its next version.
- **Source loss:** the copies do not depend on 21StarkCom after upload. A
  deleted 21StarkCom release does not break a GetEvinced install.

## Out of scope

- Builds from source and Linux builds beyond the `-linux` formulae that this
  tap already has.
- A copy of the bumper, the CI or the docs of this repo.
- Pruning of old GetEvinced releases.
- Changes to `aac`, `evinced` or the release workflows that push them.
