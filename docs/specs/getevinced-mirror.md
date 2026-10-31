# Mirror this tap to `GetEvinced/homebrew-tap`

Every entry of this tap (`21StarkCom/tap`) but the excluded ones (D11) also
lives in the Evinced tap, `GetEvinced/homebrew-tap` (`GetEvinced/tap`), with its
release asset copied into GetEvinced. A job in this repo keeps the copy in step
after each push to `main`, with no hand work. An Evinced engineer with read
access to the GetEvinced tap installs those entries with
`brew install GetEvinced/tap/<entry>` and needs no access to 21StarkCom. The
job refuses an asset that holds source (D12).

## Why

- `21StarkCom` has 16 members and `GetEvinced` has 92 (counted on
  2026-10-28). Each entry here downloads a private 21StarkCom release asset,
  so about 76 Evinced engineers cannot install the fleet today.
- The GetEvinced organization gives every member `write` on its repos by
  default, so every member can read the GetEvinced tap and its releases.
- The operator asked for a full replica: whatever this tap holds, the
  GetEvinced tap holds too.

## Before the mirror (2026-10-28)

- `GetEvinced/homebrew-tap` is private. It holds two formulae, `aac` and
  `evinced`, that build from source. The release workflows of
  `GetEvinced/infra-alerts` and `GetEvinced/evinced-cli` push them to `main`
  with one plain `git push` and no retry.
- A ruleset, `main: release-bot-only direct push` (id `17658502`), blocks
  every update, deletion and force push of `main` except by its one bypass
  actor, the `evinced-infra-cloud` GitHub App (app id `2877550`). It guards
  no other branch and no tag. Immutable releases are off.
- Each entry here pins one asset by its API URL, its `version` and its
  `sha256`, which equals the asset's `digest` in the API. The 22 assets
  totaled 2.47 GB (Atlas 492 MB, `frigg-linux` 425 MB, `frigg` 416 MB), and
  `idun` shipped 10 releases in two days.

## Decisions

| # | Decision |
|---|---|
| D1 | The replica copies each asset into GetEvinced. Its entries download from GetEvinced, never from 21StarkCom. The operator picked this on 2026-10-28. |
| D2 | This repo runs the copy, on each push to `main`. The GetEvinced tap runs nothing. The operator picked this on 2026-10-28. |
| D3 | A new GitHub App, `21stark-tap-mirror`, does the GetEvinced writes. GetEvinced owns it, it has `contents: write` and `metadata: read` only, and it is installed on `GetEvinced/homebrew-tap` only. The operator picked this on 2026-10-28. |
| D4 | The App becomes a second bypass actor of ruleset `17658502`. The ruleset and its other actor stay as they are. |
| D5 | The copies live as releases of `GetEvinced/homebrew-tap`, one release per entry and version, tag `<entry>-v<version>`. An asset keeps its source name. When that name holds other bytes in the release, the copy is `<first 12 hex of sha256>-<source name>`. |
| D6 | The job writes only files that hold the mirror marker, and the README block. It reads other files only to refuse a name clash. It never changes `aac`, `evinced` or any other unmarked file. |
| D7 | The job deletes no release and no uploaded asset. It deletes only an incomplete upload that a dead run left (untouched for an hour), which no entry can pin. A younger one may be another run's: the entry fails, and the next run retries. On 2026-10-29 STARK-13671 deleted 21 releases by hand (`gh release delete <tag> --cleanup-tag`): each release of `agent-seats`, `hermod`, `hermod-linux`, `idun`, `njord`, `sleipnir` and `valkyrie` that no entry pinned. Their assets were built before the build tickets of epic STARK-13647 took the source out, and `sleipnir-v0.43.0` also failed D12. Each asset is still in its 21StarkCom release, so a by-hand download and upload can restore it. |
| D8 | The job reads 21StarkCom with the existing `HOMEBREW_RELEASE_READ_TOKEN`. It adds no 21StarkCom credential. |
| D9 | The replica copies `Formula/` and `Casks/` only. `scripts/`, the workflows, `CLAUDE.md` and the bumper stay here. |
| D10 | The App key lives in the Actions Environment `getevinced-mirror` of this repo, which only `main` can use. A run on any other ref gets no key. |
| D11 | An entry in `EXCLUDED` (`scripts/mirror.sh`) is never copied, and a marked copy of one is deleted. Any entry that names an excluded one fails until it is excluded too. On 2026-10-28 the operator excluded `atlas`, `brain`, `librarian`, `lucius` and `odinctl`, whose assets held source or readable JS with source maps, after the first proof run had copied `brain`; that release was deleted by hand. Their build tickets (epic STARK-13647) removed the source. `atlas`, `brain`, `librarian` and `odinctl` passed D12 on 2026-10-29 and are copied. `lucius` stayed excluded until a release of it passed D12: its 0.13.0 zip still vendored `@21starkcom/stark-tui` with its TypeScript and source maps, and 0.14.0 (STARK-13791) is the first one copied. On 2026-10-29 the operator also excluded `alfred`, by request; it holds no source. The mirror run deleted its copy, and its release `alfred-v0.56.0` was deleted by hand (STARK-13795). On 2026-10-29 the `idavoll` cask was added excluded (STARK-13891): its `.pkg` holds the app's readable JavaScript. On 2026-10-31 the operator let it go (STARK-14490), that JavaScript included, so idavoll's users reach either tap. The first copy is `mac-v0.18.1`, a release after K6 (STARK-14348) took the operator's data out of the binary. |
| D12 | Before an upload, the job unpacks the asset (`.zip`, `.tar.gz` or `.pkg`) and fails the entry when a file in it is source. A `.pkg` is a xar archive: `bsdtar` unpacks it, and each member that is itself an archive (each `Payload` and `Scripts`) in its place. It finds them by their bytes, since libarchive joins a name that the table of contents gives twice (idavoll's `PayloadPayload`). The entry fails when a member whose name ends in `Payload` does not unpack, or when no such member does. An Electron `app.asar` is one file to the check. Outside `node_modules/`: a `.ts`, `.tsx`, `.mts` or `.cts` file that is no `.d.ts`, unless the entry names its path under `libexec` and its mean line is 200 bytes or more (minified: the `lucius` and `sleipnir` bundles); a `.map` file; a `.json` file that holds `sourcesContent`. Extensions match in any case. In a package under `node_modules/` whose scope is first-party (`@21starkcom`, `@atlas`, `@idun`, `@sleipnir`; the package after the last `node_modules/` of the path): such a TypeScript file or `.map` file with no exception, and a file that holds `sourcesContent`. In both places: a JS, TS or CSS file with an inline source map. Third-party packages are not read. The check cannot judge readable JS, in a bundle or inside a compiled binary; the build tickets and a red-team audit cover those. A copy uploaded before the check came in is checked by hand once (D7). |

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
- `--check <entry> <archive>` runs the D12 check of that entry on a local
  `.zip`, `.tar.gz` or `.pkg` and exits (0 passes, 1 fails), with no token
  and no network, so a release can check its asset before it ships. A
  `.pkg` needs `bsdtar`; `mirror.yml` and `bump.yml` install it.
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
2. For each `Formula/*.rb`, `Casks/*.rb` and `Casks/*/*.rb` (Homebrew reads
   `Casks/**/*.rb`; idavoll's is `Casks/i/idavoll.rb`) in this checkout but
   the D11 entries, read the asset URL, `version` and `sha256`. Use the bumper's
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
   3. Run the D12 source check. The entry fails when a file is source, and
      no release is made for it.
   4. Delete each incomplete upload in the release, by D7.
   5. When the release does not exist, create it as a draft: target `main`,
      not marked latest, and a body that names the source repo, the source
      asset id and the SHA-256.
   6. Upload the asset under its D5 name. Delete the download.
   7. Publish the draft.
5. Write the entry's file in the GetEvinced clone, at its path here. The
   file is this tap's file with the changes in "The copy of an entry" below.
6. Delete each marked GetEvinced file whose entry is no longer in this
   checkout, is a D11 entry, or moved to another path.
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

It runs on each push to `main`, once a day (which heals a failed run) and by
hand, never on another ref, one run at a time (`concurrency: mirror`, no
cancel). Job `sync` runs `scripts/mirror.sh` with `HOMEBREW_RELEASE_READ_TOKEN`
as the source token and an App token (Client ID, not the deprecated app id) as
the target token, and commits as the App's bot user. Job `verify`, on an arm
runner as in `formulae.yml`, links the GetEvinced tap in with a read-only App
token and trusts it, styles the changed copies (every copy on a daily or
manual run; not `FormulaAudit/DependencyOrder`, since rule 3 of the copy can
move a `depends_on` out of sort order), and fetches each with that token,
which checks its `sha256`. A `-linux` copy must hold a Linux x86-64
`<tool>`. A failed run sends GitHub's
failure email to the operator; the spec adds no other alert.

### Setup in GetEvinced and here

Done once, before the first run: the App `21stark-tap-mirror` in the
GetEvinced organization (private, no webhook, `contents: write`,
`metadata: read`), installed on `GetEvinced/homebrew-tap` only and added to
the bypass list of ruleset `17658502` (mode `always`); its one private key in
Mimir; and the Environment `getevinced-mirror` here (deployment branch policy
`main` only), with the variable `GETEVINCED_TAP_APP_CLIENT_ID` and the secret
`GETEVINCED_TAP_APP_KEY`.

## Testing

`scripts/test-mirror.sh` uses fixture entries only: `bump.yml` is the gate
of every bump PR, so a change to a real entry must never turn it red. For the
same reason its copy of `mirror.sh` gets its own `EXCLUDED`. Each fixture
asset is a real zip, `.tar.gz` or `.pkg` (made with `bsdtar`), against a bare
git remote and a stubbed `gh`. Each
`begin` line of the script names one case: together they cover each step and
error of `mirror.sh` above, each copy rule (checked apart from the script, by
`sed`), `aac.rb` and `evinced.rb` left byte for byte, no token in the work
directory, the `gh` log or the output, and each D12 rule, by `--check` on
fixture archives and by one run whose asset holds source.

`mirror.yml`'s `verify` job checks the copies of the real entries, and
`scripts/mirror.sh --check` checks a real asset.

## Live proof

Before the first merge (epic STARK-13601), a run on the scratch branch
`mirror-proof` wrote real releases, a token that read GetEvinced only fetched
every copy from that branch, and `tyr` was installed and tested from it, then
put back. The branch was deleted.

After a merge, the push run of `mirror.yml` copies each changed entry to
GetEvinced `main`, and a manual run checks every copy (`verify`). Homebrew 7
loads no formula from a tap that is not trusted, so a user runs
`brew trust --tap GetEvinced/tap` after `brew tap GetEvinced/tap`.

## Risks

- **Reach:** every member of GetEvinced, and each outside collaborator of
  its tap, can download every mirrored asset, Mimir and Heimdall included.
  This is the outcome the operator asked for. D12 refuses TypeScript and
  source maps, but the copied JS stays readable to a determined reader: the
  `bun build --compile` binaries embed their JS bundle, which D12 cannot
  read. D11 lists what stays out.
- **A new entry is copied by default.** The exclusion is a list in
  `scripts/mirror.sh`; an entry added to this tap reaches GetEvinced unless
  its PR adds it there, or D12 refuses its asset.
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
- **A renamed `.pkg`:** the idavoll cask's `pkg` stanza names
  `idavoll-<version>.pkg`. A rebuild under the same version gets a D5 name
  (`<sha>-idavoll-<version>.pkg`), so that copy fetches but does not install.
- **Source loss:** the copies do not depend on 21StarkCom after upload. A
  deleted 21StarkCom release does not break a GetEvinced install.

## Out of scope

- Builds from source and Linux builds beyond the `-linux` formulae that this
  tap already has.
- A copy of the bumper, the CI or the docs of this repo.
- Pruning of old GetEvinced releases.
- Changes to `aac`, `evinced` or the release workflows that push them.
