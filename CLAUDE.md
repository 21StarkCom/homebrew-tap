# CLAUDE.md

Add only rules, traps and pointers here. Put reasons, history and catalogs in `docs/` or the ticket.

Public Homebrew tap for the 21Stark fleet (`21StarkCom/homebrew-tap`, tapped as `21StarkCom/tap`). It is a passive publish target: it builds nothing, and each entry pins one GitHub Release asset. Every entry is public: it pins its release of this tap.

- `README.md` holds the catalogs: the Entries table (kind, build, signing and macOS floor of each entry), the caller table (the release step that bumps each entry), and one section per entry. Read it before you change an entry.
- A CLI is a formula in `Formula/`. A GUI `.app` is a cask in `Casks/`, never a formula.
- Keep `Casks/i/idavoll.rb` in its subfolder: idavoll's Fleet CLIs step installs each `Casks/*.rb` and must never install idavoll itself.
- The atlas cask has no `binary` stanza: its bundled CLI must not shadow the `brain` formula.

## Downloads

- An entry downloads, with no token code, from its release `<entry>-v<version>` here. Its line `# Source release repo: <owner>/<repo>` names the repo the bumper reads (`docs/specs/public-tap.md`).
- The bumper checks the asset with `scripts/source-check.pl`, then publishes that release before it pins it. A public asset cannot be called back.
- A new entry starts public. Before its first publish, unpack its asset, dump the strings of each Mach-O or ELF file, run `gitleaks dir` over it, and read each finding.
- An asset that holds a secret stays private. Before you add a private entry, read its shape and traps in the README's Public entries section.
- Trap: PRs and Actions logs here are public. Keep each secret value out of them.
- Never override `_fetch` or run curl in the tap: Homebrew owns preflight, redirects, cache freshness and partial resume.

## Release fields and the bumper

- `version`, the `url` and `sha256` change each release. Do not hand-edit them: each source repo's release runs `scripts/bump.sh`, which reads them back from the published release and opens a PR here.
- `scripts/bump.sh --help` is the bumper's reference: its flags, PR titles and the `no-ticket` label.
- Keep the standalone `url "…",`, `version "…"` and `sha256 "…"` stanzas, each exactly once: the bumper refuses an entry with more or fewer. It finds each one by an anchored regex, so their order is free.
- Never move the `url` into a helper or interpolate the version into it: the bumper rewrites the literal.
- To re-point an entry by hand, run the bumper from a clean checkout of this repo at `origin/main` (`--dry-run` previews, `--no-pr` edits the checkout without a commit).
- Callers run `main` unpinned, so the bumper's interface only grows.
- A bumper change lands with its tests (`scripts/test-bump.sh`) in the same PR.
- Keep `scripts/bump.sh` working under bash 3.2: a signing Mac runs it as `/bin/bash`.

## Platform

- A macOS entry declares `depends_on :macos` and `depends_on arch: :arm64`.
- A `<tool>-linux` formula is the tool's unsigned Linux build for the devbox, with `depends_on :linux` and `depends_on arch: :x86_64`. It is a separate entry because `brew style` refuses a `url` inside `on_macos`/`on_linux`.
- Name a new `-linux` formula after the binary it ships: CI requires its zip to hold `<tool>` as a Linux x86-64 executable.
- Trap: a `-linux` bump without the entry's `--asset-suffix` (the README's caller table) pins the macOS zip.

## Commands

```sh
# Install: no entry needs a token
brew install 21StarkCom/tap/idun

# Lint and audit an edit, from the repo root
brew style Formula/idun.rb
# --except=version, as CI: a url can make the bumper's `version` line "redundant"
brew audit --strict --except=version 21StarkCom/tap/idun
# A -linux formula: audit it as Linux x86_64 (CI does); reinstall and test it on the devbox
brew audit --strict --except=version --os=linux --arch=intel 21StarkCom/tap/<tool>-linux

# A cask's audit skips the unversioned-URL check, as CI does; atlas also needs `,token_conflicts`
brew fetch --cask 21StarkCom/tap/atlas        # checks the registered clone's pinned sha256
brew audit --cask --strict --except=sha256_no_check_if_unversioned 21StarkCom/tap/atlas

# A real install, and the `test do` block
brew reinstall 21StarkCom/tap/idun && brew test 21StarkCom/tap/idun

# Preview a bump; run the bumper's tests (BUMP_TEST_BASH=/bin/bash runs bash 3.2)
scripts/bump.sh <entry> <tag> --dry-run
scripts/test-bump.sh

# Preview a mirror run (Homebrew's bash, MIRROR_TARGET_TOKEN set; no source token)
scripts/mirror.sh --dry-run
```

## Checks

- The registered tap is a separate git clone at `/opt/homebrew/Library/Taps/21starkcom/homebrew-tap`, not a symlink to this checkout. Never discard another process's changes in that shared clone.
- `brew style <path>` checks this working tree.
- Trap: it can also load the clone's copy of the entry and flag `Lint/DuplicateMethods` on `install` or `caveats`. When `main`'s unchanged file shows it too, add `--except-cops Lint/DuplicateMethods`.
- `brew audit` rejects a path. `brew audit --strict 21StarkCom/tap/<name>` and `brew fetch --cask 21StarkCom/tap/<name>` read the registered clone.
- `brew fetch --cask <path>` works only under `HOMEBREW_DEVELOPER=1`: use it to check an edited cask's download against its `sha256`.
- Check syntax and style before you merge.
- After the merge, confirm the clone is clean, fast-forward it to the merged entry, confirm it has the reviewed version, url and checksum, and run the audit.
- Homebrew trusts this tap per entry: `brew trust --json=v1` lists the trusted entries.
- Trap: `brew audit` and `brew fetch` refuse a new entry copied into the clone until `brew trust --formula 21starkcom/tap/<name>` (`--cask` for a cask). `brew install` of the full name trusts it.
- CI installs and tests no entry. Run `brew reinstall` and `brew test` on a Mac, and on the x86_64 devbox for a `-linux` formula.
- Keep `test do` version-agnostic: assert `version.to_s` against the tool's own `version` output, never a fixed string.
- CI fetches only the entries a PR changes. A change of `scripts/` or `formulae.yml`, or `gh workflow run formulae.yml`, fetches all.
- Trap: the fetch catches a gone asset or a mismatched `sha256`, but not a url and checksum of another release. Check the version yourself.

## PRs

- Pass `--ticket STARK-<n>` to the bumper when a ticket covers the bump: it puts the ticket in the PR title.
- A bump PR that a ticket covers but that opened unscoped needs a retitle and its `no-ticket` label dropped, in one command (`gh pr edit <n> --title … --remove-label no-ticket`): `ghx pr-merge` reads the live title, and skips its ticket stamp while the label stays.
- A bump PR is a release bot's PR under the root review rules. Bumpers open it with plain `gh pr create`, so `ghx pr-open`'s checks never ran on it: before you merge, check that its diff changes only the entry's three release lines, and that the url and checksum match the release.
- The secret scan may flag a formula's public 64-hex checksum as high-entropy. Check it against the downloaded release bytes before you pass `--allow-secret-commit` to `ghx pr-open`.

## Adding a formula (or cask)

- Copy an existing entry of the same shape. Point its source line at the new repo; `homepage` stays this tap.
- `bin.install` names each shipped binary: `bin.install "alfred", "alfredd"`, or a glob such as `Dir["lumiere", "lumiere-*"]`. A bare dispatcher name needs its own literal, since `lumiere-*` does not match it.
- The bumper never creates an entry: the first PR pins `version`, the `url` and `sha256` to the first release. Once the file exists, `scripts/bump.sh <entry> <tag> --no-pr` publishes the asset and fills them in.
- Update `README.md` in the same PR, the caller table included.
- Check the name against homebrew/core and homebrew/cask (`brew info homebrew/cask/<name>`). A name that collides (a bare `valkyrie` or `sleipnir` is a homebrew/cask app) is named in full, `21StarkCom/tap/<name>`, in every `brew` command.

**Node-ESM CLI → formula** (`Formula/brain.rb` is the model):

- The release zip is a node ESM tree (`dist/` and a vendored `node_modules` with the signed native modules) plus any run-time data the CLI reads from disk.
- `install` runs `libexec.install Dir["*"]`, which keeps the layout and the relative pnpm symlinks. It writes a `bin` wrapper that runs the entry under `depends_on "node"`: `exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"`.
- Trap: Homebrew renames each keg dylib to its `opt` path, and fails when that name does not fit the header. `install` renames such a dylib to `@rpath/<name>` and re-signs it ad hoc.
- Such a formula declares `preserve_rpath`, which keeps that name, as `Formula/floorplan.rb` does.

**Bun bundle-tree CLI → formula** (`Formula/sleipnir.rb` is the model):

- The release zip is the runnable tree at its top level: minified Bun bundles, their run-time files and a vendored prod `node_modules`. It holds no TypeScript source.
- `install` runs `libexec.install Dir["*"]`, which skips top-level dotfiles: keep the zip free of them. It writes a `bin` wrapper over `depends_on "bun"`: `exec "#{formula_opt_bin("bun")}/bun" "#{libexec}/bin/<entry>.mjs" "$@"`.
- The bumper never rewrites the wrappers: a launcher move is a hand edit in that release's tap PR.
- Add `--no-env-file --config=/dev/null` when the CLI must not inherit the caller's cwd `.env` or `bunfig.toml` preloads, and keep a matching `test do` assertion.
- Trap: `brew install` sets no minimum version on a dependency, so a stale homebrew/core bottle can miss a Bun floor that the CLI enforces at run time. Only `brew test` catches it.

**GUI `.app` → cask** (`Casks/mimir.rb` is the model):

- `app "X.app"` places the bundle in `/Applications`.
- `binary "#{appdir}/X.app/Contents/Resources/bin/<cli>"` symlinks a nested CLI onto PATH. Never copy it: the CLI resolves its own path to find the bundle executable it pins.
- `depends_on macos:` pins the build's deployment target.
- `uninstall quit:` closes the app, and any menu bar helper it opens (a login item with its own bundle id), on upgrade. Never name a `KeepAlive` launchd agent there: launchd relaunches it at once.
- Put every launchd job the app registers, its login item included, in `zap launchctl:`, never in `uninstall launchctl:`: `brew upgrade` runs every `uninstall` directive but `signal` too.
- Trap: a helper's own `SMAppService.mainApp` registration owns no launchd job while the helper is quit, and outlives its bundle. Zap it with `login_item:` by display name.
- A `login_item:` zap makes System Events ask the terminal for Automation access.
- The release zip holds the notarized and **stapled** `.app` at its root: Homebrew installs a cask's app quarantined on each install or upgrade, and the stapled ticket lets Gatekeeper check it offline.

## The GetEvinced mirror

- After each push to `main`, `mirror.yml` copies each entry to `GetEvinced/homebrew-tap`. A public entry's copy keeps its url; only a private entry's asset is copied there. Every member of the GetEvinced org can read what lands there.
- `docs/specs/getevinced-mirror.md` is the mirror's design. `scripts/mirror.sh --help` lists what the copy changes and what its source check refuses.
- Run `scripts/mirror.sh --check <entry> <archive>` on a new entry's release zip, `.tar.gz` or `.pkg` before its PR (a `.pkg` needs `bsdtar`).
- Add a fleet repo's new npm scope to `FIRST_PARTY_SCOPES` in `scripts/source-check.pl`.
- The check cannot judge readable JS: an unminified bundle, the JS inside a `bun build --compile` binary, or an Electron `app.asar`. The PR that adds a private entry whose asset holds readable JS also adds it to `EXCLUDED` in `scripts/mirror.sh`, unless the operator says it may go.
- Every entry that `EXCLUDED` does not hold is copied, a new one included.
- Keep `# frozen_string_literal: true` and a blank line as an entry's first two lines: the copy puts its marker line after them.
- Name another fleet entry only as `21StarkCom/tap/<entry>`, which the copy renames to `GetEvinced/tap/<entry>`.
- An entry that names an excluded one (`21StarkCom/tap/alfred`) must be excluded too: `mirror.sh` fails it until it is.
- Mimir's item `GitHub App - 21stark-tap-mirror` holds the key of record of the mirror's GitHub App.

## CI

- `bump.yml`'s test fails when the bumper's `GATE_WORKFLOWS` differs from the workflows here that trigger on `pull_request`, or when one of them filters that trigger. Keep each such trigger unfiltered, and add a new one to `GATE_WORKFLOWS` in the same PR.
- `mirror.yml` has no `pull_request` trigger and stays out of `GATE_WORKFLOWS`: `bump.yml` runs `scripts/test-mirror.sh` on each PR instead.
- `brew style … scripts` lints `scripts/*.sh` with every optional shellcheck check and Homebrew's `shfmt` layout (`brew style --fix scripts/bump.sh` applies it).
- Trap: that layout pass misreads a line inside a string or heredoc that starts with `if`. Keep embedded jq, Ruby and stub code free of those.
- `formulae.yml`'s fetch steps pass the Actions secret `HOMEBREW_RELEASE_READ_TOKEN` as the token, and fetch with none when it is empty (a fork's PR). A private entry's source repo must grant it contents-read access.
