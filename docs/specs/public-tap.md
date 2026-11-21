# The public tap, `21StarkCom/public`

Anyone can install some entries of this tap with no GitHub login:

```sh
brew tap 21StarkCom/public
brew install 21StarkCom/public/<entry>
```

`21StarkCom/homebrew-public` is a public repo that holds a copy of each public
entry and of its release asset. This repo and the source repos stay private.
`scripts/mirror.sh --target public` makes the copies, as it makes the GetEvinced
copies (`docs/specs/getevinced-mirror.md`). This spec names only what differs
from that spec. STARK-19531 holds the work.

## Why

- GitHub keeps the release assets of a private repo private. A download with no
  token answers `404`, so a public tap of this repo alone gives no binaries.
- The common practice for a closed-source CLI is a public tap whose recipes
  download from a public URL with no token. The tap's own releases are that URL.
- The operator approved this design on 2026-11-21.

## Decisions

| # | Decision |
|---|---|
| P1 | The public tap is the new repo `21StarkCom/homebrew-public`. Terraform makes it (`repos/repos.tf` in `21StarkCom/21stark`), with the secret-scan files of wave 4, whose commit makes its `main`. |
| P2 | `PUBLIC_ENTRIES` in `scripts/mirror.sh` is an allow list. An entry that it does not name stays out, a new one included, and a marked copy of it is deleted. `EXCLUDED` wins over it. |
| P3 | An entry goes on the list only when its asset holds no readable JS. On 2026-11-21 the list is the twelve Go formulae and `mimir`, whose binary embeds its web UI as minified JS. `goldfinger` stays out: its Safari extension holds a readable `background.js`. The entries in `bun build --compile` binaries, node ESM trees, Bun bundles and Electron apps stay out. |
| P4 | A new GitHub App, `21stark-public-tap`, does the writes. 21StarkCom owns it. It has `contents: write` and `metadata: read` only, and it is installed on `homebrew-public` only. Its key is in the mimir item `GitHub App - 21stark-public-tap`, and in the secret `PUBLIC_TAP_APP_KEY` of the Environment `public-tap` here, which only `main` can use. The repo variable `PUBLIC_TAP_APP_CLIENT_ID` turns the jobs on. |
| P5 | A copy downloads from the browser URL of its public release, `https://github.com/21StarkCom/homebrew-public/releases/download/<entry>-v<version>/<asset name>`, with no token. That URL holds the version, and it uses no API rate limit. |
| P6 | `mirror.sh` makes each public copy before it uploads the entry's asset, and an entry whose copy fails uploads nothing: a public asset cannot be called back. |
| P7 | The release body names the entry, its version, its asset name and its SHA-256. It does not name the source repo or the source asset id. |

## The copy of an entry

The copy is the source file with the marker line of the GetEvinced copy, and
these changes:

1. The asset URL becomes the URL of P5. Its one argument line goes: a `headers:`
   array on that line, or a `using:` class. An entry fails when its `url` has
   another argument, or more than one.
2. In a formula, the token lookup goes: the `worker = …` statement (one line, or
   a `do` block) with the comment block right above it, the
   `token = worker ? "" : …` line, and the `if token.empty? && !worker … end`
   block. Each line of that comment block is about the asset pin, the bumper or
   the token.
3. In a cask, the download adapter goes: `require "download_strategy"`, the
   comment above the class, and the class `… < CurlDownloadStrategy`.
4. The comment `# API asset URL (private repo)…` goes, and so do the other known
   lines that explain the token lookup.
5. The caveat that asks for GitHub read access goes: the two heredoc lines and
   the blank line after them, or a one-line `caveats`. A `caveats` heredoc left
   empty goes, and so does a blank line left before the last `end`.
6. `homepage` becomes `https://github.com/21StarkCom/homebrew-public`: the source
   repo is private.
7. Each `21starkcom/tap`, in any case, becomes `21starkcom/public` in the same
   case.
8. An entry fails when its copy still holds `GitHub::API`, `Authorization:`,
   `CurlDownloadStrategy`, `api.github.com/repos/`, `HOMEBREW_GITHUB_API_TOKEN`,
   `private repos` or `21starkcom/tap`. Then its token code has a shape that
   rules 1 to 5 do not know: fix the rules, not the copy.

## The README

A new README starts with `# 21StarkCom/public`. The block that `mirror.sh` owns
gives the install commands with no token note, and a table of the entries with
their kind and version.

## The workflow

`mirror.yml` gets two jobs, which run only when `PUBLIC_TAP_APP_CLIENT_ID` is set:

- `public-sync` runs `scripts/mirror.sh --target public` with an App token for
  `homebrew-public`.
- `public-verify` taps `21StarkCom/public` with `brew tap`, with no token and no
  `gh` login. It styles the changed copies, fetches each one, and checks the
  `sha256`.

## Testing

`scripts/test-mirror.sh` gets cases for each rule above. Its fixtures carry the
token code of the real entries, in both `worker` shapes, and a cask adapter.
Each expected copy is written out by hand. The GetEvinced cases do not change.

## Live proof

On a Mac with no GitHub credential, `brew tap 21StarkCom/public`, then
`brew install 21StarkCom/public/tyr` and `brew test 21StarkCom/public/tyr`.

## Risks

- **Reach:** anyone can download each public asset and read its binary. P3
  keeps readable JS out, but a determined reader can still read machine code.
- **A wrong list entry is public for good.** Check an asset with
  `scripts/mirror.sh --check <entry> <archive>`, and look for readable JS by hand,
  before its PR adds it to `PUBLIC_ENTRIES`.
- **Key leak:** a leaked key of `21stark-public-tap` can write to the public tap,
  and the Ruby in its files runs on each Mac that installs from it.
- **Stale homepage notes:** comments in a copy that do not name the token (such
  as the mimir note on the API asset id) stay as they are.

## Not built

- Pruning of old public releases.
- A public copy of the `-linux` entries' Bun builds, or of any entry with
  readable JS.
- Bottles: each copy still downloads the release asset.
