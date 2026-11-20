# CLAUDE.md

Add only rules, traps and pointers here. Put reasons, history and catalogs in `docs/` or the ticket.

Private Homebrew tap for the 21Stark fleet (`21StarkCom/homebrew-tap`, tapped as `21StarkCom/tap`). It is a passive publish target: it builds nothing, and each entry pins one private GitHub Release asset.

- `README.md` holds the catalogs: the Entries table (kind, build, signing and macOS floor of each entry), the caller table (the release step that bumps each entry), and one section per entry. Read it before you change an entry.
- A CLI is a formula in `Formula/`. A GUI `.app` is a cask in `Casks/`, never a formula.
- Keep `Casks/i/idavoll.rb` in its subfolder: idavoll's Fleet CLIs step installs each `Casks/*.rb` and must never install idavoll itself.
- The atlas cask has no `binary` stanza: its bundled CLI must not shadow the `brain` formula.

## Downloads

- Each entry puts `Accept: application/octet-stream` and a stripped token from Homebrew's own lookup on its GitHub API asset URL. The lookup is `GitHub::API.credentials`: `HOMEBREW_GITHUB_API_TOKEN`, else `gh auth token` from Homebrew's own gh (the only gh it looks for), else a keychain token.
  - A formula passes them as `headers:` on its `url`.
  - A cask keeps a small initialization-only adapter that sets the same download metadata, because `brew info --json` prints cask URL headers verbatim.
- Never override `_fetch` or run curl in the tap: Homebrew owns preflight, redirects, cache freshness and partial resume.
- When the lookup finds nothing, the entry raises `CurlDownloadStrategyError.new(url, guidance)`: a formula when it is evaluated, so formula metadata commands need a token too, and a cask when its downloader starts.
- Homebrew's sandboxed `build.rb`, `test.rb` and `postinstall.rb` workers reload the formula with gh's config (`~/.config/gh`) and the login keychain unreadable, and never download. Formulae skip the lookup and the raise in them, and match a worker by its full path under `HOMEBREW_LIBRARY_PATH` (the path `Sandbox.ruby_command` launches it by).
- Do not hand those workers the token through `ENV`: Homebrew restores `ENV` after it evaluates a formula.
- Trap: Homebrew redacts only `ENV` secrets. With a gh-only login, `--verbose --debug` and `HOMEBREW_CURL_VERBOSE` print the gh token in the curl command line: do not paste that output.

## Release fields and the bumper

- `version`, the numeric asset id in the `url`, and `sha256` change each release. Do not hand-edit them: each source repo's release runs `scripts/bump.sh`, which reads them back from the published release and opens a PR here.
- `scripts/bump.sh --help` is the bumper's reference: its flags, PR titles and the `no-ticket` label.
- Keep the standalone `url "…",`, `version "…"` and `sha256 "…"` stanzas, each exactly once: the bumper refuses an entry with more or fewer. It finds each one by an anchored regex, so their order is free.
- Keep the auth headers as continuation arguments of the `url`. Never move the asset pin into a helper or interpolate the version into it.
- To re-point an entry by hand, run the bumper from a clean checkout of this repo at `origin/main` (`--dry-run` previews, `--no-pr` edits the checkout without a commit).
- Callers run `main` unpinned, so the bumper's interface only grows. A bumper change lands with its tests (`scripts/test-bump.sh`) in the same PR.
- Keep `scripts/bump.sh` working under bash 3.2: a signing Mac runs it as `/bin/bash`.

## Platform

- An entry declares `depends_on :macos` and `depends_on arch: :arm64`.
- A `<tool>-linux` formula is the tool's unsigned Linux build for the devbox, with `depends_on :linux` and `depends_on arch: :x86_64`. It is a separate entry because `brew style` refuses a `url` inside `on_macos`/`on_linux`.
- Name a new `-linux` formula after the binary it ships: CI requires its zip to hold `<tool>` as a Linux x86-64 executable.
- Trap: a `-linux` bump without the entry's `--asset-suffix` (the README's caller table) pins the macOS zip.

## Commands

```sh
# Install (consumer) — token needs read access to 21StarkCom private repos
brew install gh && gh auth login    # or: export HOMEBREW_GITHUB_API_TOKEN=<github PAT>
brew install 21StarkCom/tap/idun

# Lint / audit a formula edit (run from repo root)
brew style Formula/idun.rb
brew audit --strict 21StarkCom/tap/idun       # --online also checks the URL/homepage, but reports
                                              # every private asset URL "not reachable": check it with brew fetch
# A -linux formula is Linux x86_64 only: audit it as that (CI does), and reinstall
# and test it on the devbox, since a Mac refuses to install it
brew audit --strict --os=linux --arch=intel 21StarkCom/tap/hermod-linux 21StarkCom/tap/frigg-linux 21StarkCom/tap/urd-linux \
  21StarkCom/tap/idun-linux 21StarkCom/tap/njord-linux 21StarkCom/tap/valkyrie-linux 21StarkCom/tap/utgard-linux \
  21StarkCom/tap/sonar-linux

# Same for the cask (a GUI app). A cask's asset-id URL fails the unversioned-URL
# audit by design, and atlas also needs `,token_conflicts` (homebrew/core's atlas)
brew style Casks/mimir.rb
brew fetch --cask 21StarkCom/tap/mimir        # checks the registered clone's pinned sha256
brew audit --cask --strict --except=sha256_no_check_if_unversioned 21StarkCom/tap/mimir

# Exercise the real install + the formula's `test do` block (needs the token)
brew reinstall 21StarkCom/tap/idun
brew test 21StarkCom/tap/idun

# Preview a bump (any checkout), and run the bumper's tests (local only: a bare
# remote and a stubbed gh; BUMP_TEST_BASH=/bin/bash runs bump.sh under bash 3.2)
scripts/bump.sh <entry> <tag> --dry-run
scripts/test-bump.sh

# Preview a mirror run (Homebrew's bash, MIRROR_TARGET_TOKEN set; no source token)
scripts/mirror.sh --dry-run
```

## Checks

- The registered tap is a separate git clone at `/opt/homebrew/Library/Taps/21starkcom/homebrew-tap`, not a symlink to this checkout. Never discard another process's changes in that shared clone.
- `brew style <path>` checks this working tree. It can also load the clone's copy of the same class and report `Lint/DuplicateMethods` on `install` or `caveats`: when `main`'s unchanged file shows the same offense, rerun with `--except-cops Lint/DuplicateMethods`.
- `brew audit` rejects a path. `brew audit --strict 21StarkCom/tap/<name>` and `brew fetch --cask 21StarkCom/tap/<name>` read the registered clone.
- `brew fetch --cask <path>` works only under `HOMEBREW_DEVELOPER=1`: use it to check an edited cask's download against its `sha256`.
- Check syntax and style before you merge. After the merge, confirm the clone is clean, fast-forward it to the merged entry, confirm it has the reviewed version, asset id and checksum, and run the audit.
- Homebrew trusts this tap per entry (`brew trust --json=v1`). It refuses to load a new entry copied into the clone for `brew audit` and `brew fetch` until `brew trust --formula 21starkcom/tap/<name>`. `brew install` of the full name trusts it.
- CI installs and tests no entry. Run `brew reinstall` and `brew test` on a Mac, and on the x86_64 devbox for a `-linux` formula.
- A change to the sandboxed workers' skip needs a Mac's `brew reinstall` and `brew test` under a gh-only login: CI's Linux Homebrew never loads those workers for an entry.
- Keep `test do` version-agnostic: assert `version.to_s` against the tool's own `version` output, never a fixed string.
- CI fetches only the entries a PR changes; a change of `scripts/` or `formulae.yml`, or a manual run (`gh workflow run formulae.yml`), fetches every entry. The fetch catches a gone asset and a hand-edited asset id or `sha256` that no longer match. An id and a checksum that agree but belong to another release pass: check the version against the release yourself.

## PRs

- Pass `--ticket STARK-<n>` to the bumper when a ticket covers the bump: it puts the ticket in the PR title.
- A bump PR that a ticket covers but that opened unscoped needs a retitle and its `no-ticket` label dropped, in one command (`gh pr edit <n> --title … --remove-label no-ticket`): `njord pr-merge` reads the live title, and skips its ticket stamp while the label stays.
- A bump PR is a release bot's PR under the root review rules. Bumpers open it with plain `gh pr create`, so `njord pr-open`'s checks never ran on it: before you merge, check that its diff changes only the entry's three release lines, and that the asset id and checksum match the release.
- The secret scan may flag a formula's public 64-hex checksum as high-entropy. Check it against the downloaded release bytes before you pass `--allow-secret-commit` to `njord pr-open`.

## Adding a formula (or cask)

- Copy an existing entry of the same shape. Keep its native auth headers and token check, and point `homepage` and `url` at the new private repo.
- `bin.install` names each shipped binary: `bin.install "alfred", "alfredd"`, or a glob such as `Dir["lumiere", "lumiere-*"]`. A bare dispatcher name needs its own literal, since `lumiere-*` does not match it.
- The bumper never creates an entry: the first PR pins `version`, the asset id and `sha256` to the first release. Once the file exists, `scripts/bump.sh <entry> <tag> --no-pr` fills them in.
- Update `README.md` in the same PR, the caller table included.
- Check the name against homebrew/core and homebrew/cask (`brew info homebrew/cask/<name>`). A name that collides (a bare `valkyrie` or `sleipnir` is a homebrew/cask app) is named in full, `21StarkCom/tap/<name>`, in every `brew` command.

**Node-ESM CLI → formula** (`Formula/brain.rb` is the model):

- The release zip is a node ESM tree (`dist/` and a vendored `node_modules` with the signed native modules) plus any run-time data the CLI reads from disk.
- `install` runs `libexec.install Dir["*"]`, which keeps the layout and the relative pnpm symlinks. It writes a `bin` wrapper that runs the entry under `depends_on "node"`: `exec "#{formula_opt_bin("node")}/node" "#{libexec}/dist/bin.js" "$@"`.
- Trap: Homebrew renames each dylib in the keg to its `opt` path, and fails the install when the name does not fit the header. For such a dylib, `install` renames it to `@rpath/<name>` and re-signs it ad hoc, under `preserve_rpath` (`Formula/floorplan.rb`). Then the sandboxed `fix_linkage` worker, `sandbox_operation.rb`, reloads the formula: add it to the formula's worker list.

**Bun bundle-tree CLI → formula** (`Formula/sleipnir.rb` is the model):

- The release zip is the runnable tree at its top level: minified Bun bundles, their run-time files and a vendored prod `node_modules`. It holds no TypeScript source, since the GetEvinced mirror refuses source.
- `install` runs `libexec.install Dir["*"]`, which skips top-level dotfiles: keep the zip free of them. It writes a `bin` wrapper over `depends_on "bun"`: `exec "#{formula_opt_bin("bun")}/bun" "#{libexec}/bin/<entry>.mjs" "$@"`.
- The bumper never rewrites the wrappers: a launcher move is a hand edit in that release's tap PR.
- Add `--no-env-file --config=/dev/null` when the CLI must not inherit the caller's cwd `.env` or `bunfig.toml` preloads, and keep a matching `test do` assertion.
- Trap: Homebrew cannot set a minimum version on a formula dependency. A Bun floor that the CLI enforces at run time is invisible to `brew install`: a Mac with a stale homebrew/core pours an old bottle, and only `brew test` catches it.

**GUI `.app` → cask** (`Casks/mimir.rb` is the model):

- Keep a uniquely named initialization-only adapter, like `MimirPrivateReleaseStrategy`, that sets `@meta[:headers]`, so the cask JSON shows no credential.
- `app "X.app"` places the bundle in `/Applications`.
- `binary "#{appdir}/X.app/Contents/Resources/bin/<cli>"` symlinks a nested CLI onto PATH. Never copy it: the CLI resolves its own path to find the bundle executable it pins.
- `depends_on macos:` pins the build's deployment target.
- `uninstall quit:` closes the app, and any menu bar helper it opens (a login item with its own bundle id), on upgrade. Never name a `KeepAlive` launchd agent there: launchd relaunches it at once.
- Put every launchd job the app registers, its login item included, in `zap launchctl:`, never in `uninstall launchctl:`: `brew upgrade` runs every `uninstall` directive but `signal` too.
- A helper's own `SMAppService.mainApp` registration owns no launchd job while the helper is quit, and outlives its bundle. Zap it with `login_item:` by display name; System Events then asks the terminal for Automation access.
- The release zip holds the notarized and **stapled** `.app` at its root: Homebrew installs a cask's app quarantined on each install or upgrade, and the stapled ticket lets Gatekeeper check it offline.

## The GetEvinced mirror

- After each push to `main`, `mirror.yml` copies each entry, with its release asset, to `GetEvinced/homebrew-tap`. Every member of the GetEvinced org can read what lands there.
- `docs/specs/getevinced-mirror.md` is the mirror's design. `scripts/mirror.sh --help` lists what the copy changes and what its source check refuses.
- Run `scripts/mirror.sh --check <entry> <archive>` on a new entry's release zip, `.tar.gz` or `.pkg` before its PR (a `.pkg` needs `bsdtar`). Add a fleet repo's new npm scope to `FIRST_PARTY_SCOPES` in the same script.
- The check cannot judge readable JS: an unminified bundle, the JS inside a `bun build --compile` binary, or an Electron `app.asar`. The PR that adds an entry whose asset holds readable JS also adds it to `EXCLUDED` in `scripts/mirror.sh`, unless the operator says it may go.
- Every entry that `EXCLUDED` does not hold is copied, a new one included.
- Keep `# frozen_string_literal: true` and a blank line as an entry's first two lines: the copy puts its marker line after them.
- Name another fleet entry only as `21StarkCom/tap/<entry>`, which the copy renames to `GetEvinced/tap/<entry>`.
- An entry that names an excluded one (`21StarkCom/tap/alfred`) must be excluded too: `mirror.sh` fails it until it is.
- Mimir's item `GitHub App - 21stark-tap-mirror` holds the key of record of the mirror's GitHub App.

## CI

- `bump.yml`'s test fails when the bumper's `GATE_WORKFLOWS` differs from the workflows here that trigger on `pull_request`, or when one of them filters that trigger. Keep each such trigger unfiltered, and add a new one to `GATE_WORKFLOWS` in the same PR.
- `mirror.yml` has no `pull_request` trigger and stays out of `GATE_WORKFLOWS`: `scripts/test-mirror.sh` checks both.
- `brew style … scripts` lints `scripts/*.sh` with every optional shellcheck check and Homebrew's `shfmt` layout (`brew style --fix scripts/bump.sh` applies it).
- Trap: that layout pass misreads a line inside a string or heredoc that starts with `if`. Keep embedded jq, Ruby and stub code free of those.
- `formulae.yml` reads each release with the Actions secret `HOMEBREW_RELEASE_READ_TOKEN`, and fails when it cannot: a new entry's source repo must grant that token contents-read access.
