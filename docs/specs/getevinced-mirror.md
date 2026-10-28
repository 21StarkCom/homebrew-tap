# Mirror this tap to `GetEvinced/homebrew-tap`

Every entry of this tap (`21StarkCom/tap`) also lives in the Evinced tap,
`GetEvinced/homebrew-tap` (`GetEvinced/tap`), with its release asset copied
into GetEvinced. A job in this repo keeps the copy in step after each push to
`main`, with no hand work. An Evinced engineer with read access to the
GetEvinced tap installs the fleet with `brew install GetEvinced/tap/<entry>`
and needs no access to 21StarkCom.

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
  `GetEvinced/infra-alerts` and `GetEvinced/evinced-cli` push them to `main`.
- A ruleset, `main: release-bot-only direct push`, blocks every update of
  `main` except by its one bypass actor, the `evinced-infra-cloud` GitHub
  App (app id `2877550`). That App has `administration: write` and
  `contents: write` on every GetEvinced repo.
- The GetEvinced tap has no Actions secrets or variables.
- This tap holds 19 formulae and 3 casks. Each one pins one asset by its API
  URL (`https://api.github.com/repos/21StarkCom/<repo>/releases/assets/<id>`),
  its `version` and its `sha256`.
- Each source asset reports its SHA-256 in the API (`digest`), and it equals
  the `sha256` the entry pins. The largest asset is the Atlas cask's zip,
  492 MB.
- Entries name this tap in their text: `librarian` has
  `depends_on "21starkcom/tap/brain"`, and the `sleipnir`, `mimir`,
  `goldfinger` and `atlas` texts tell the user to run
  `brew install 21StarkCom/tap/<entry>` or say that installing needs
  "read access to 21StarkCom private repos".

## Decisions

| # | Decision |
|---|---|
| D1 | The replica copies each asset into GetEvinced. Its entries download from GetEvinced, never from 21StarkCom. The operator picked this on 2026-10-28. |
| D2 | This repo runs the copy, on each push to `main`. The GetEvinced tap runs nothing. The operator picked this on 2026-10-28. |
| D3 | A new GitHub App, `21stark-tap-mirror`, does the GetEvinced writes. GetEvinced owns it, it has `contents: write` and `metadata: read` only, and it is installed on `GetEvinced/homebrew-tap` only. The operator picked this on 2026-10-28. |
| D4 | The App becomes a second bypass actor of the GetEvinced ruleset. The ruleset and its other actor stay as they are. |
| D5 | The copies live as releases of `GetEvinced/homebrew-tap`, one release per entry and version, tag `<entry>-v<version>`. The asset keeps its source name. |
| D6 | The job owns a GetEvinced file only when the file holds the mirror marker. It never reads or writes `aac`, `evinced` or any other unmarked file. |
| D7 | The job keeps the three newest GetEvinced releases of each entry, plus any release an entry pins. It deletes the others. |
| D8 | The job reads 21StarkCom with the existing `HOMEBREW_RELEASE_READ_TOKEN`. It adds no 21StarkCom credential. |
| D9 | The replica copies `Formula/` and `Casks/` only. `scripts/`, the workflows, `CLAUDE.md` and the bumper stay here. |

## Design

### Parts

| Part | What it does |
|---|---|
| `scripts/mirror.sh` | Makes the GetEvinced tap match this checkout. Idempotent: a second run with no change in between does nothing. |
| `scripts/test-mirror.sh` | Tests `mirror.sh` against a bare git remote and a stubbed `gh`, as `scripts/test-bump.sh` does. |
| `.github/workflows/mirror.yml` | Runs `mirror.sh`, then proves the changed entries download from GetEvinced. |
| `.github/workflows/bump.yml` | Gets one more job that runs `scripts/test-mirror.sh` on each pull request. |

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
- `--branch` names the GetEvinced branch to push. The default is `main`. The
  live proof uses a scratch branch.
- `--dry-run` prints the plan and writes nothing.
- `--only` limits the run to the named entries, for a retry by hand.
- The script writes the changed entries to `$GITHUB_OUTPUT` when that file
  is set, as `formulae` and `casks`, one space-separated list each.
- `--help` is its reference, as for `bump.sh`.

Steps, in this order:

1. Clone the GetEvinced branch with `MIRROR_TARGET_TOKEN`.
2. For each `Formula/*.rb` and `Casks/*.rb` in this checkout, read the asset
   URL, `version` and `sha256`. Use the bumper's anchored URL pattern
   (`URL_RE` in `scripts/bump.sh`). Stop with an error when an entry has
   other than one `url`, `version` or `sha256` stanza.
3. Find the GetEvinced release `<entry>-v<version>`. Find its asset whose
   `digest` is `sha256:<pinned sha256>` and whose state is `uploaded`.
4. When no such asset exists:
   1. Download the source asset with `MIRROR_SOURCE_TOKEN`.
   2. Compare its SHA-256 with the pinned `sha256`. Stop with an error when
      they differ.
   3. Create the release when it does not exist: target `main`, not marked
      latest, and a body that names the source repo, the source asset id
      and the SHA-256.
   4. Delete an asset of the same name with another digest or an
      incomplete upload. It is an old copy or a failed run.
   5. Upload the asset under its source name.
5. Write the entry's file in the GetEvinced clone. The file is this tap's
   file with the changes in "The copy of an entry" below.
6. Delete each marked GetEvinced file whose entry is no longer in this
   checkout. Leave the releases of that entry in place.
7. Write the README block (below).
8. Commit all changes in one commit and push it. On a rejected push, fetch,
   rebase and push again, up to three times.
9. After the push, delete old releases by D7.

Errors:

- An unmarked GetEvinced file with the name of an entry here stops the run
  before any write.
- An entry that still names `21starkcom/tap` after the copy rules stops the
  run before any write.
- A failure in one entry stops the run before the push. Uploads that
  already finished stay, and the next run reuses them.
- The script uploads all assets before it pushes. So a pushed entry never
  points at an asset that does not exist.

### The copy of an entry

The copy is the source file with these changes, and no others:

1. A marker line goes after the `# frozen_string_literal: true` line and a
   blank line:
   `# Mirrored from 21StarkCom/homebrew-tap by scripts/mirror.sh. Do not edit: the next run overwrites it.`
2. The asset URL becomes
   `https://api.github.com/repos/GetEvinced/homebrew-tap/releases/assets/<copy id>`.
3. Each `21starkcom/tap/`, in any case, becomes `getevinced/tap/`, in the
   case of the source text (`21StarkCom/tap/` becomes `GetEvinced/tap/`).
   This keeps `librarian`'s dependency on `brain` inside the GetEvinced tap.
4. `read access to 21StarkCom private repos` becomes
   `read access to GetEvinced private repos`.

`version`, `sha256`, `homepage`, the token lookup, the sandboxed-worker
skip and each cask's download adapter stay the same. The `homepage` still
names the 21StarkCom source repo, because that repo is the source.

A user with both taps loads a cask adapter, for example
`MimirPrivateReleaseStrategy`, from two files. The two definitions are the
same, so Ruby reopens the class with no change.

### The README block

The script owns one block of the GetEvinced `README.md`, between
`<!-- BEGIN 21stark-mirror -->` and `<!-- END 21stark-mirror -->`. It adds the
block at the end of the file on the first run. The block holds:

- one line that says the 21StarkCom mirror job writes the block and the
  marked files, and that a change made there is lost at the next run;
- the install commands: `brew install GetEvinced/tap/<entry>` and
  `brew install --cask GetEvinced/tap/<cask>`;
- the token note: Homebrew's `gh` signed in to an account with read access
  to `GetEvinced/homebrew-tap`, or `HOMEBREW_GITHUB_API_TOKEN`;
- a note that a Mac with both taps must use full names, for example
  `GetEvinced/tap/idun`;
- a table with a row per entry: name, kind (formula or cask), version and
  source repo.

The rest of the README stays as the Evinced team wrote it.

### `.github/workflows/mirror.yml`

- Triggers: `push` to `main`, `workflow_dispatch`, and one `schedule` run a
  day. The daily run heals a run that failed and was not seen.
- `concurrency`: one group, `mirror`, with `cancel-in-progress: false`.
  GitHub keeps one pending run, and it is always the newest push.
- Job `sync`, on `ubuntu-latest`:
  1. Check out this repo with `persist-credentials: false`.
  2. Mint an App token with `actions/create-github-app-token`, pinned by
     SHA: `owner: GetEvinced`, `repositories: homebrew-tap`.
  3. Run `scripts/mirror.sh` with `MIRROR_SOURCE_TOKEN` from
     `HOMEBREW_RELEASE_READ_TOKEN` and `MIRROR_TARGET_TOKEN` from the App
     token. Commit as the App's bot user.
- Job `verify`, on `ubuntu-24.04-arm`, after `sync`, when `sync` changed an
  entry. The daily run checks every entry:
  1. Put Homebrew on `PATH` and run `brew update`, as `formulae.yml` does.
  2. Mint an App token with read access to `homebrew-tap`.
  3. Tap `GetEvinced/tap` over HTTPS with that token, and trust it.
  4. Run `brew style` on the changed copies.
  5. Run `brew fetch` on each changed formula and `brew fetch --cask` on
     each changed cask, with the App token as `HOMEBREW_GITHUB_API_TOKEN`.
     Each fetch checks the download against the pinned `sha256`.
  6. For a changed `-linux` formula, check that the download holds a
     Linux x86-64 `<tool>`, as `formulae.yml` does.

### Setup in GetEvinced and here

1. Create the App `21stark-tap-mirror` in the GetEvinced organization:
   private, no webhook, `contents: write`, `metadata: read`.
2. Install it on `GetEvinced/homebrew-tap` only.
3. Add it to the bypass list of the ruleset `main: release-bot-only direct
   push`, mode `always`.
4. Make one private key. Store it in Mimir.
5. Set this repo's Actions variable `GETEVINCED_TAP_APP_ID` and Actions
   secret `GETEVINCED_TAP_APP_KEY`.

Steps 1 and 2 need a browser session of a GetEvinced owner. Steps 4 and 5
handle a secret value, so they need the operator's GO.

## Testing

`scripts/test-mirror.sh` covers:

- a first run into an empty tap: all entries, releases and the README block;
- a second run with no change: no upload, no commit;
- a version bump of one entry: one upload, one changed file;
- a reused asset: the release has a matching digest, so no download;
- a SHA-256 mismatch on download: an error, and no push;
- an incomplete upload left by a failed run: the script deletes and
  replaces it;
- an entry removed here: its marked file goes, its releases stay;
- an unmarked GetEvinced file with an entry's name: an error, no write;
- `aac.rb` and `evinced.rb` stay byte for byte the same;
- the copy rules on a copy of `librarian.rb`, `sleipnir.rb` and
  `Casks/mimir.rb`;
- a rejected push that succeeds after a rebase;
- pruning: three newest releases kept, a pinned older release kept;
- `--dry-run`: no write of any kind.

## Live proof

Before merge, from this checkout, with the operator's `gh` login as both
tokens (the operator is an owner of both organizations):

```sh
scripts/mirror.sh --branch mirror-proof
```

This writes real releases, which the first run on `main` reuses, and a
scratch branch, `mirror-proof`, that the ruleset does not guard. Then, on
the operator's Mac, a scratch tap named `getevinced/mirror-proof` checks out
that branch and runs:

- `brew fetch` of every formula and `brew fetch --cask` of every cask;
- `brew install` and `brew test` of one formula that the Mac does not have
  from this tap, then `brew uninstall` of it.

Cleanup: `brew untap getevinced/mirror-proof` and delete the branch
`mirror-proof`.

After merge: the push run of `mirror.yml` copies every entry to GetEvinced
`main`. The ticket gets the run link, the GetEvinced commit, and the output
of `brew tap GetEvinced/tap` and `brew fetch GetEvinced/tap/idun` on the
operator's Mac.

## Risks

- **Reach:** every member of GetEvinced, and each outside collaborator of
  its tap, can download every mirrored binary, Mimir and Heimdall included.
  This is the outcome the operator asked for.
- **Key leak:** a leaked key of `21stark-tap-mirror` reaches one repo. It can
  still push to that repo's `main`, `aac` and `evinced` included.
- **Lag:** GetEvinced trails this tap by one workflow run: a few minutes,
  most of it the upload of the new asset. A run that fails leaves it one
  release behind until the next run.
- **Step 1 of the copy:** each entry starts with
  `# frozen_string_literal: true` today (checked on 2026-10-28). An entry
  without that line stops the run, so the marker never lands above it.
- **Source loss:** the copies do not depend on 21StarkCom after upload. A
  deleted 21StarkCom release does not break a GetEvinced install.
- **Storage:** D7 keeps at most three copies of each asset, about 1.5 GB for
  Atlas.

## Out of scope

- Builds from source and Linux builds beyond the `-linux` formulae that this
  tap already has.
- A copy of the bumper, the CI or the docs of this repo.
- Changes to `aac`, `evinced` or the release workflows that push them.
