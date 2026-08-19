# homebrew-tap

Private [Homebrew](https://brew.sh) tap for the 21Stark fleet.

## lumiere

The [`lumiere`](https://github.com/21StarkCom/lumiere) visual-media CLI toolkit —
16 `lumiere-*` tools (image gen/edit, SVG suite, video, brand icons, …).

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a GitHub PAT with read access to 21StarkCom>
brew install 21StarkCom/tap/lumiere
```

The token is required: this repo and the `lumiere` releases are **private**, and
the formula's `GitHubPrivateReleaseStrategy` fetches the release asset by its
GitHub API URL with an `Authorization` header.

**macOS arm64 only.** The bottle is a Developer-ID-signed + notarized
`darwin_arm64` build (Apple Silicon). Linux users build from source in the
`lumiere` repo (`make build`).

## Maintenance — the formula is bumped automatically

`Formula/lumiere.rb` pins the release's darwin zip **asset id + sha256**, both of
which change every release. Do **not** hand-edit them. They are rewritten by
`lumiere`'s release tooling:

- `scripts/release-darwin.sh <version>` (run on the Mac that holds the signing
  cert) builds, signs, notarizes, and uploads the macOS zip, then calls…
- `scripts/bump-tap.sh <version>`, which reads the asset id + sha256 back from the
  published release, rewrites the three release-specific lines, and opens a PR
  here.

To re-point at an existing release by hand, run `scripts/bump-tap.sh <version>`
from the `lumiere` checkout (`--dry-run` to preview).
