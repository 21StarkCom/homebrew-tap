#!/usr/bin/env bash
# scripts/bump.sh: this tap's one bumper. It points a Formula/ or Casks/ entry at
# a published GitHub Release and opens (or reuses) the bump PR here, optionally
# waiting for this tap's checks and squash-merging it. The design is ADR-0008
# (21stark docs/adr/0008-shared-tap-bumper.md); `scripts/bump.sh --help` is the
# reference. Tests: scripts/test-bump.sh.
#
# Only bash builtins, git, gh, perl, and sha256sum or shasum (Decision 1): every
# caller, the Linux release jobs included, has exactly those.
#
# brew style (formulae.yml) lints this with every optional shellcheck check. Three
# are off: single-quoted $names are jq's, not the shell's (SC2016); functions run
# from conditions return their own status on purpose (SC2310); a case with no
# match has nothing to do (SC2249).
# shellcheck disable=SC2016,SC2249,SC2310
set -euo pipefail

TAP_REPO="21StarkCom/homebrew-tap"
# The fleet's below-the-ticket-bar mark. njord pr-merge skips its ticket stamp
# only for a PR carrying it; unlabeled, the stamp falls back to whatever ticket
# the merging session is bound to. publish_pr syncs it to the PR's final title.
NO_TICKET_LABEL="no-ticket"
# A title that names a ticket, as njord pr-merge reads one (TICKET_PREFIX_RE in
# the idun repo's apps/njord/src/lib/draft_schema.ts, matched against the
# trimmed title).
TICKET_TITLE_RE='^[a-z]+\([A-Z][A-Z0-9]{1,9}-[0-9]+\)!?:'
# Every workflow this tap runs on a pull request: --merge waits for all of them
# (Decision 4). scripts/test-bump.sh fails when this differs from the
# .github/workflows/ files that trigger on pull_request.
GATE_WORKFLOWS="bump.yml formulae.yml secret-scan.yml"
# 240 polls 5 s apart (Decision 4). The tests shorten both.
POLL_BUDGET="${BUMP_POLL_BUDGET:-240}"
POLL_SECONDS="${BUMP_POLL_SECONDS:-5}"

ENTRY_RE='^[A-Za-z0-9][A-Za-z0-9@+._-]*$'
# An optional non-digit prefix (v, cli-v), then X.Y.Z[-pre]: BASH_REMATCH[2].
TAG_RE='^([A-Za-z][A-Za-z._-]*)?([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?)$'
URL_RE='^[[:space:]]*url[[:space:]]+"https://api\.github\.com/repos/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/releases/assets/[0-9]+"'
# A public entry (docs/specs/public-tap.md) downloads from a public release of
# this tap, and names its source repo in a comment.
PUBLIC_URL_RE='^[[:space:]]*url[[:space:]]+"https://github\.com/21StarkCom/homebrew-tap/releases/download/[^"/]+/[^"/]+"'
SOURCE_RE='^[[:space:]]*#[[:space:]]*Source release repo:[[:space:]]*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)[[:space:]]*$'
# No +: the upload passes the name unencoded in a query, where + reads as a space.
ASSET_NAME_RE='^[A-Za-z0-9._@-]+$'
VERSION_RE='^[[:space:]]*version[[:space:]]+"([^"]*)"'
NL=$'\n'

entry="" tag="" version="" ticket="" suffix="darwin_arm64.zip"
dry_run=false no_pr=false merge=false npos=0
tap_root="" rel="" repo="" pinned="" tmp="" restore_ref="" branch=""
a_id="" a_name="" sha="" pr="" pushed="" public=false pub_tag="" pub_url=""

usage() {
  local text
  IFS= read -r -d '' text <<'EOF' || true
Usage: scripts/bump.sh [flags] <entry> <tag> [flags]
       scripts/bump.sh [flags] -- <entry> <tag>

Point one entry of this tap at a published GitHub Release, then open a PR here.
The checkout this script sits in is the one it reads and edits: clone the tap
(depth 1 is enough) and run the script from that clone.

  <entry>             exactly one of Formula/<entry>.rb, Casks/<entry>.rb and
                      Casks/<first character>/<entry>.rb
  <tag>               the release tag, verbatim (v1.2.3, cli-v1.2.3). The version
                      is the tag without its leading non-digit prefix, and must
                      be X.Y.Z or X.Y.Z-<pre>.
  --ticket STARK-<n>  scope the commit and PR title:
                      chore(STARK-<n>): bump <entry> to <tag>
                      The PR is labeled no-ticket exactly when its title names
                      no ticket (see the no-ticket label, below).
  --asset-suffix <s>  the asset to pin (default darwin_arm64.zip)
  --dry-run           print the diff to stderr and change nothing
  --no-pr             edit this checkout's entry, with no commit and no PR
  --merge             open the PR, wait for this tap's checks, and squash-merge
  -h, --help, help    print this and exit
Flags go before or after the two positionals; `--` ends them.

The release repo is the one the entry's asset url names. The release must carry
exactly one asset ending in the suffix. It is downloaded by id and hashed, and
its <asset>.sha256 sidecar and GitHub's digest, when present, must agree with
that hash. The entry's version, asset url and sha256 lines must each occur once.

A public entry (docs/specs/public-tap.md) downloads with no token from a public
release of this tap: its url is
https://github.com/21StarkCom/homebrew-tap/releases/download/<entry>-v<version>/<asset>,
and one line `# Source release repo: <owner>/<repo>` names the release repo.
Its asset must pass scripts/source-check.pl, since a public asset cannot be
called back. Then it is published as the release <entry>-v<version> of this
tap: a draft first, the upload read back against the hash, then published. A
release that already holds the asset's name with that hash is reused; other
bytes under the name stop the run. --dry-run publishes nothing; --no-pr and a
PR run publish before they edit the entry. The token needs Contents: write on
this tap for that.

A PR run needs this checkout clean (no tracked edits) and at origin's main. It
pushes bump/<entry>-<version> and opens a PR, or reuses the one open on that
branch: its body is refreshed, and its title only with --ticket. An existing
branch is rebuilt from main only while it is one commit ahead of main that
changes nothing but those three lines; any other branch is a human's edit, and
the run refuses it. Nothing is opened when main already pins the release, or
pins a newer X.Y.Z. The checkout ends the run back on the ref it started on.

The no-ticket label: every PR run syncs it to the PR's final title, read as idun
gh pr-merge reads one: a title naming no ticket carries it, any other does not.
A PR opened without --ticket gets it once open. --ticket retitles a reused PR
first and then drops it, so a failure never leaves it unlabeled and unscoped.
A reused PR re-run without --ticket keeps its live title and gains or loses the
label to match. A failed add or drop is a warning that names the command, and
the next run on the branch retries it; a failed retitle stops the run.

--merge merges only once every workflow this tap runs on pull requests (bump,
formulae, secret-scan) has a run for the PR's exact head that concluded
success, with gh pr merge --squash --delete-branch --match-head-commit. A head
that moves while it waits is gated afresh, and only if it is still the bumper's
own one-commit shape. It fails at once on a closed PR, a failed run, a conflict
or a human's head, and gives up after 240 polls 5 s apart. Reading the runs
needs Actions: read on the token.

stdout: the PR number and nothing else. Empty means there is nothing to merge.
Exit: 0 done or nothing to do, 1 refused or failed, 2 usage error.
Needs bash, git, gh, perl, and sha256sum or shasum.
EOF
  printf '%s' "${text}"
}

say() { printf '%s\n' "$*" >&2; }
die() {
  say "bump.sh: $*"
  exit 1
}
usage_error() {
  say "bump.sh: $*"
  say "Run scripts/bump.sh --help for usage."
  exit 2
}

take_positional() {
  npos=$((npos + 1))
  case "${npos}" in
    1) entry="$1" ;;
    2) tag="$1" ;;
    *) usage_error "expected <entry> <tag>, got a third positional: $1" ;;
  esac
}

pause() { perl -e 'select undef, undef, undef, $ARGV[0]' "${POLL_SECONDS}"; }

copy_file() { perl -MFile::Copy -e 'copy($ARGV[0], $ARGV[1]) or die "copy $ARGV[0]: $!\n"' "$1" "$2"; }

sha256_of() {
  local out
  if command -v sha256sum >/dev/null 2>&1
  then
    out="$(sha256sum "$1")"
  else
    out="$(shasum -a 256 "$1")"
  fi
  printf '%s\n' "${out%% *}"
}

# Is $1's X.Y.Z core older than $2's? Pre-release parts never compare (I11).
core_older() {
  local IFS=. a b left=3
  # shellcheck disable=SC2086 # split both cores on '.' into six fields
  set -- ${1%%-*} ${2%%-*}
  while [[ "${left}" -gt 0 ]]
  do
    a=$((10#$1)) b=$((10#$4))
    if [[ "${a}" -ne "${b}" ]]
    then
      [[ "${a}" -lt "${b}" ]]
      return
    fi
    shift
    left=$((left - 1))
  done
  return 1
}

# The checkout goes back to the ref the run started on (I15), and the local bump
# branch goes: the remote one carries the bump.
restore_checkout() {
  [[ -n "${restore_ref}" ]] || return 0
  local ref="${restore_ref}"
  restore_ref=""
  if ! git -C "${tap_root}" checkout -q HEAD -- "${rel}" || ! git -C "${tap_root}" checkout -q "${ref}"
  then
    say "bump.sh: could not switch ${tap_root} back to ${ref}"
  fi
  git -C "${tap_root}" branch -q -D "${branch}" >/dev/null 2>&1 || true
}

cleanup() {
  local rc=$?
  # The exit contract is 0, 1 or 2: an unexpected tool failure is a failure.
  case "${rc}" in 0 | 1 | 2) ;; *) rc=1 ;; esac
  restore_checkout
  if [[ -n "${tmp}" ]]
  then
    perl -MFile::Path=remove_tree -e 'remove_tree($ARGV[0])' "${tmp}" || true
  fi
  exit "${rc}"
}

# The entry's release repo, from its one asset url line (a public entry: its
# source line), and the version it pins.
read_entry() {
  local line urls=0 publics=0 sources=0 source=""
  while IFS= read -r line || [[ -n "${line}" ]]
  do
    if [[ ${line} =~ ${URL_RE} ]]
    then
      urls=$((urls + 1))
      repo="${BASH_REMATCH[1]}"
    elif [[ ${line} =~ ${PUBLIC_URL_RE} ]]
    then
      publics=$((publics + 1))
    elif [[ ${line} =~ ${SOURCE_RE} ]]
    then
      sources=$((sources + 1))
      source="${BASH_REMATCH[1]}"
    elif [[ -z "${pinned}" ]] && [[ ${line} =~ ${VERSION_RE} ]]
    then
      pinned="${BASH_REMATCH[1]}"
    fi
  done <"${tap_root}/${rel}"
  [[ $((urls + publics)) -eq 1 ]] || die "${rel}: want one release asset url line, found $((urls + publics))"
  [[ "${publics}" -eq 1 ]] || return 0
  [[ "${sources}" -eq 1 ]] ||
    die "${rel}: a public entry needs one '# Source release repo: <owner>/<repo>' line, found ${sources}"
  public=true
  repo="${source}"
}

# I3: a PR run starts from a clean checkout at origin's main.
check_checkout() {
  local dirty remote_main head
  git -C "${tap_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "${tap_root} is not a git checkout; a PR run needs a clone of ${TAP_REPO}"
  dirty="$(git -C "${tap_root}" status --porcelain --untracked-files=no)"
  [[ -z "${dirty}" ]] || die "the tap checkout has tracked edits; a PR run needs it clean:${NL}${dirty}"
  remote_main="$(git -C "${tap_root}" ls-remote --exit-code origin refs/heads/main)" ||
    die "could not read origin's main from ${tap_root}"
  remote_main="${remote_main%%[[:space:]]*}"
  head="$(git -C "${tap_root}" rev-parse HEAD)"
  [[ "${head}" = "${remote_main}" ]] ||
    die "the tap checkout is at ${head:0:12}, not origin's main ${remote_main:0:12}; check out main and pull"
}

# I6, I10: one read of the release supplies every asset field; exactly one asset
# matches the suffix; it is downloaded by id and hashed, and the sidecar and
# GitHub's digest must agree with that hash.
resolve_asset() {
  local line kind size state digest s_id s_state s_count _end got side
  say "==> reading ${repo} ${tag}"
  line="$(gh api "repos/${repo}/releases/tags/${tag}" --jq '
    [.assets[] | select(.name | endswith("'"${suffix}"'"))] as $a
    | if ($a | length) != 1 then
        ["count", ($a | length), ([$a[].name] | join(", ")), "."] | map(tostring) | join("\u001f")
      else $a[0] as $z
        | [.assets[] | select(.name == $z.name + ".sha256")] as $s
        | ["ok", $z.id, $z.name, $z.size, $z.state, ($z.digest // ""),
           ($s[0].id // ""), ($s[0].state // ""), ($s | length), "."]
        | map(tostring) | join("\u001f")
      end')" || die "could not read release ${tag} on ${repo}"
  IFS=$'\x1f' read -r kind a_id a_name size state digest s_id s_state s_count _end <<<"${line}"
  [[ "${kind}" = ok ]] ||
    die "${repo} ${tag} must carry exactly one *${suffix} asset, found ${a_id}${a_name:+: ${a_name}}"
  [[ ${a_id} =~ ^[0-9]+$ ]] || die "asset id is not numeric: ${a_id}"
  [[ "${state}" = uploaded ]] || die "${a_name} is not fully uploaded (state ${state})"
  [[ "${s_count}" -le 1 ]] || die "${repo} ${tag} carries ${s_count} ${a_name}.sha256 sidecars"

  say "==> downloading ${a_name} (asset ${a_id})"
  gh api -H 'Accept: application/octet-stream' "repos/${repo}/releases/assets/${a_id}" >"${tmp}/asset" ||
    die "could not download asset ${a_id}"
  got="$(perl -e 'print -s $ARGV[0]' "${tmp}/asset")" || die "could not size ${tmp}/asset"
  [[ "${got}" = "${size}" ]] || die "downloaded ${got} bytes of ${a_name}, the release lists ${size}"
  sha="$(sha256_of "${tmp}/asset")" || die "could not hash ${a_name}"
  [[ ${sha} =~ ^[0-9a-f]{64}$ ]] || die "could not hash ${a_name} (got '${sha}')"
  if [[ -n "${digest}" ]] && [[ "${digest}" != "sha256:${sha}" ]]
  then
    die "GitHub's digest ${digest} does not match the downloaded ${a_name} (sha256 ${sha})"
  fi
  if [[ -n "${s_id}" ]]
  then
    [[ "${s_state}" = uploaded ]] || die "${a_name}.sha256 is not fully uploaded (state ${s_state})"
    gh api -H 'Accept: application/octet-stream' "repos/${repo}/releases/assets/${s_id}" >"${tmp}/sidecar" ||
      die "could not download ${a_name}.sha256"
    side=""
    read -r side _ <"${tmp}/sidecar" || true
    [[ "${side}" = "${sha}" ]] || die "${a_name}.sha256 reads '${side}', the downloaded ${a_name} hashes to ${sha}"
  fi
  say "    ${a_name}  id=${a_id}  sha256=${sha}${s_id:+ (sidecar agrees)}${digest:+ (digest agrees)}"
}

# A public entry's asset must pass the source check before it is published: a
# public asset cannot be called back.
check_source_files() {
  local hits
  say "==> checking ${a_name} for source (scripts/source-check.pl)"
  [[ -f "${tap_root}/scripts/source-check.pl" ]] || die "${tap_root}/scripts/source-check.pl is missing"
  hits="$(perl "${tap_root}/scripts/source-check.pl" --entry "${tap_root}/${rel}" --archive "${tmp}/asset" 2>"${tmp}/check.err")" ||
    die "the source check of ${a_name} did not run: $(<"${tmp}/check.err")"
  [[ -n "${hits}" ]] || return 0
  die "${a_name} holds source, so it is not published:${NL}${hits}"
}

# A public entry's asset becomes the asset of the release <entry>-v<version> of
# this tap. A new release is a draft until the upload reads back against the
# hash, then it is published. A release that holds the name with this hash is
# reused; other bytes under the name stop the run: a public asset is never
# replaced. A draft left by a failed run has no tag yet, so a new draft is made.
publish_asset() {
  local found rid="" draft=false p_id="" p_state="" p_digest="" p_name="" _end got up err
  # The published release of the tag: its id, and the id, state and digest of
  # its asset of this name (ASSET_NAME_RE keeps the name safe in the jq string).
  if found="$(gh api "repos/${TAP_REPO}/releases/tags/${pub_tag}" --jq '
     ([.assets[] | select(.name == "'"${a_name}"'")][0] // {}) as $a
     | [.id, ($a.id // ""), ($a.state // ""), ($a.digest // ""), "."] | map(tostring) | join("\u001f")' 2>"${tmp}/gh.err")"
  then
    IFS=$'\x1f' read -r rid p_id p_state p_digest _end <<<"${found}"
  else
    err="$(<"${tmp}/gh.err")"
    [[ ${err} == *"HTTP 404"* ]] || die "could not read release ${pub_tag} on ${TAP_REPO}: ${err}"
  fi
  if [[ -n "${p_id}" ]]
  then
    [[ "${p_state}" = uploaded ]] ||
      die "release ${pub_tag} of ${TAP_REPO} holds ${a_name} in state ${p_state}: delete that asset, and run again"
    if [[ -z "${p_digest}" ]]
    then
      gh api -H 'Accept: application/octet-stream' "repos/${TAP_REPO}/releases/assets/${p_id}" >"${tmp}/published" ||
        die "could not download ${a_name} of release ${pub_tag} to check it"
      got="$(sha256_of "${tmp}/published")" || die "could not hash ${a_name} of release ${pub_tag}"
      p_digest="sha256:${got}"
    fi
    [[ "${p_digest}" = "sha256:${sha}" ]] ||
      die "release ${pub_tag} of ${TAP_REPO} already holds other bytes as ${a_name} (${p_digest}, not sha256:${sha}); a public asset is never replaced"
    say "==> release ${pub_tag} already holds ${a_name}; reusing it"
    return 0
  fi
  if [[ -z "${rid}" ]]
  then
    say "==> making the draft release ${pub_tag} on ${TAP_REPO}"
    rid="$(gh api -X POST "repos/${TAP_REPO}/releases" -f tag_name="${pub_tag}" -f target_commitish=main \
      -f name="${entry} ${version}" -F draft=true -f make_latest=false \
      -f body="The release asset \`${a_name}\` of \`${entry}\` ${version}, SHA-256 \`${sha}\`, published by scripts/bump.sh for the public entry \`${rel}\`." \
      --jq .id)" || die "could not make the draft release ${pub_tag} on ${TAP_REPO}"
    [[ ${rid} =~ ^[0-9]+$ ]] || die "the draft release ${pub_tag} has no numeric id (got '${rid}')"
    draft=true
  fi
  say "==> uploading ${a_name} to release ${pub_tag}"
  up="$(gh api -X POST -H 'Content-Type: application/octet-stream' --input "${tmp}/asset" \
    "https://uploads.github.com/repos/${TAP_REPO}/releases/${rid}/assets?name=${a_name}" \
    --jq '[.id, .state, (.digest // ""), .name, "."] | map(tostring) | join("\u001f")')" ||
    die "could not upload ${a_name} to release ${pub_tag}"
  IFS=$'\x1f' read -r p_id p_state p_digest p_name _end <<<"${up}"
  # GitHub renames an asset whose name holds special characters: the pinned url would 404.
  [[ "${p_name}" = "${a_name}" ]] || die "GitHub stored the upload of ${a_name} to ${pub_tag} as '${p_name}'"
  [[ "${p_state}" = uploaded ]] || die "the upload of ${a_name} to ${pub_tag} reads back as state '${p_state}'"
  if [[ -z "${p_digest}" ]]
  then
    gh api -H 'Accept: application/octet-stream' "repos/${TAP_REPO}/releases/assets/${p_id}" >"${tmp}/published" ||
      die "could not download the upload of ${a_name} to check it"
    got="$(sha256_of "${tmp}/published")" || die "could not hash the upload of ${a_name}"
    p_digest="sha256:${got}"
  fi
  [[ "${p_digest}" = "sha256:${sha}" ]] ||
    die "the upload of ${a_name} to ${pub_tag} reads back as ${p_digest}, not sha256:${sha}"
  if ${draft}
  then
    gh api -X PATCH "repos/${TAP_REPO}/releases/${rid}" -F draft=false -f make_latest=false >/dev/null ||
      die "uploaded ${a_name}, but could not publish the draft release ${pub_tag}: publish it on ${TAP_REPO}'s releases page"
  fi
  say "==> published ${pub_url}"
}

# I5: each of the three lines matches exactly once, or nothing is written. The
# rewrite goes to a copy, so the checkout is untouched until a mode writes it (I1).
rewrite_entry() {
  ENTRY="${rel}" REPO="${repo}" VER="${version}" ASSET="${a_id}" SHA="${sha}" PUB="${pub_url}" perl -0777 -pe '
    my $repo = quotemeta $ENV{REPO};
    # A public entry pins the release of this tap; any other, its source asset.
    my $urls = $ENV{PUB} ne ""
      ? scalar(s{^([ \t]*url[ \t]+)"https://github\.com/21StarkCom/homebrew-tap/releases/download/[^"/\n]+/[^"/\n]+"}{$1"$ENV{PUB}"}mg)
      : scalar(s{^([ \t]*url[ \t]+"https://api\.github\.com/repos/$repo/releases/assets/)[0-9]+"}{$1$ENV{ASSET}"}mg);
    my %n = (
      "version"   => scalar(s{^([ \t]*version[ \t]+)"[^"]*"}{$1"$ENV{VER}"}mg),
      "asset url" => $urls,
      "sha256"    => scalar(s{^([ \t]*sha256[ \t]+)"[^"]*"}{$1"$ENV{SHA}"}mg),
    );
    for (sort keys %n) {
      ($n{$_} || 0) == 1 or die "$ENV{ENTRY}: want one $_ line, found " . ($n{$_} || 0) . "\n";
    }' "${tap_root}/${rel}" >"$1"
}

# Decision 6: an existing bump branch is the bumper's own only while it is one
# commit ahead of main that changes nothing but the entry's three lines. Read
# through the compare API, so nothing is checked out (I15). Prints the tip's tree.
bumper_shape() {
  local out ahead tree files patch
  # One line of "<ahead_by> <tip tree> <changed files>", then the patch.
  out="$(gh api "repos/${TAP_REPO}/compare/main...$1" --jq \
    '"\(.ahead_by) \(.commits[-1].commit.tree.sha) \([.files[].filename] | join(","))\n\(.files[0].patch // "")"')" || {
    say "    could not compare main...$1 on ${TAP_REPO}"
    return 1
  }
  read -r ahead tree files <<<"${out%%"${NL}"*}"
  patch="${out#*"${NL}"}"
  if [[ "${ahead}" != 1 ]]
  then
    say "    it is ${ahead} commits ahead of main, not 1"
    return 1
  fi
  if [[ "${files}" != "${rel}" ]]
  then
    say "    it changes ${files:-nothing}, not ${rel} alone"
    return 1
  fi
  REPO="${repo}" perl -ne '
    BEGIN { $r = quotemeta $ENV{REPO}; $bad = 0; $n = 0 }
    next if /^$/ || /^ / || /^@@ / || /^\\ No newline/;
    $n++;
    $bad++ unless /^[-+][ \t]*(version[ \t]+"[^"]*"|url[ \t]+"https:\/\/api\.github\.com\/repos\/$r\/releases\/assets\/[0-9]+",?|url[ \t]+"https:\/\/github\.com\/21StarkCom\/homebrew-tap\/releases\/download\/[^"\/]+\/[^"\/]+"|sha256[ \t]+"[0-9a-f]{64}")[ \t]*$/;
    END { exit($bad || !$n ? 1 : 0) }' <<<"${patch}" || {
    say "    its commit changes more than the version, asset url and sha256 lines:"
    say "${patch}"
    return 1
  }
  printf '%s\n' "${tree}"
}

# Commit the rewrite on bump/<entry>-<version>, push it, and open or reuse its PR.
publish_pr() {
  local scope="chore" title body tip tip_tree="" tree url found pr_marked=false pr_title="" final_title
  [[ -z "${ticket}" ]] || scope="chore(${ticket})"
  title="${scope}: bump ${entry} to ${tag}"
  body="Point \`${rel}\` at \`${a_name}\` (asset \`${a_id}\`, sha256 \`${sha}\`) from ${repo} ${tag}."
  ! ${public} || body="${body} It is published as the release \`${pub_tag}\` of this tap: ${pub_url}"
  branch="bump/${entry}-${version}"

  tip="$(git -C "${tap_root}" ls-remote origin "refs/heads/${branch}")" || die "could not read ${branch} from origin"
  tip="${tip%%[[:space:]]*}"
  # The open PR on the branch, if any: its number, whether it carries the
  # no-ticket mark (matched as idun matches it: trimmed, any case), and its live
  # title (a human may have retitled it).
  found="$(gh pr list -R "${TAP_REPO}" --head "${branch}" --base main --state open --json number,title,labels \
    --jq '.[0] // empty | [.number, any(.labels[]; .name | test("^\\s*'"${NO_TICKET_LABEL}"'\\s*$"; "i")), .title]
      | map(tostring) | join("\u001f")')" || die "could not list the open PRs on ${branch}"
  pr=""
  [[ -z "${found}" ]] || IFS=$'\x1f' read -r pr pr_marked pr_title <<<"${found}"
  if [[ -n "${tip}" ]]
  then
    tip_tree="$(bumper_shape "${tip}")" ||
      die "${branch}${pr:+ (PR #${pr})} exists and is not this bumper's own one-commit bump (above), so it may hold a human's edit: refusing to replace it. Finish that PR by hand, or close it and delete the branch."
  fi

  # I4, I15: the branch is built from main's tip with checkout -B, whatever a
  # failed run left behind, and the checkout switches back once it is pushed.
  restore_ref="$(git -C "${tap_root}" symbolic-ref -q HEAD || git -C "${tap_root}" rev-parse HEAD)" ||
    die "could not read the checkout's HEAD"
  restore_ref="${restore_ref#refs/heads/}"
  # Started on the bump branch itself (at main's tip, per I3): come back detached
  # at that tip, since the branch is about to hold the bump commit.
  [[ "${restore_ref}" != "${branch}" ]] || restore_ref="$(git -C "${tap_root}" rev-parse HEAD)"
  git -C "${tap_root}" checkout -q -B "${branch}" || die "could not create ${branch}"
  copy_file "${tmp}/updated" "${tap_root}/${rel}" || die "could not write ${rel}"
  git -C "${tap_root}" add -- "${rel}" || die "could not stage ${rel}"
  git -C "${tap_root}" commit -q -m "${title} (asset ${a_id})" >&2 || die "could not commit ${rel}"
  pushed="$(git -C "${tap_root}" rev-parse HEAD)" || die "could not read the bump commit"
  tree="$(git -C "${tap_root}" rev-parse 'HEAD^{tree}')" || die "could not read the bump commit's tree"
  if [[ -n "${tip}" ]] && [[ "${tip_tree}" = "${tree}" ]]
  then
    say "==> ${branch} already carries this bump; reusing it as it stands"
    pushed="${tip}"
  else
    # I13: the refspec names the bump branch alone. The lease is the tip read
    # above (empty: the branch must not exist yet).
    say "==> pushing ${branch}"
    git -C "${tap_root}" push -q --force-with-lease="refs/heads/${branch}:${tip}" origin \
      "refs/heads/${branch}:refs/heads/${branch}" >&2 || die "could not push ${branch}"
  fi
  restore_checkout

  if [[ -n "${pr}" ]]
  then
    say "==> reusing PR #${pr}"
    if [[ -n "${ticket}" ]]
    then
      # Retitle first; the sync below drops the mark after. A failure between
      # the two leaves a ticket title that still carries the mark, which only
      # skips idun's stamp, never an unscoped, unmarked PR it would stamp with
      # the merging session's bound ticket.
      gh pr edit "${pr}" -R "${TAP_REPO}" --title "${title}" --body "${body}" >&2 || die "could not retitle PR #${pr}"
      final_title="${title}"
    else
      gh pr edit "${pr}" -R "${TAP_REPO}" --body "${body}" >&2 ||
        say "bump.sh: warning: could not refresh PR #${pr}'s body; it may name the previous asset"
      final_title="${pr_title}"
    fi
  else
    url="$(gh pr create -R "${TAP_REPO}" --base main --head "${branch}" --title "${title}" --body "${body}")" ||
      die "could not open a PR for ${branch}"
    say "==> opened ${url}"
    pr="${url##*/}"
    final_title="${title}"
  fi
  case "${pr}" in
    "" | *[!0-9]*) die "could not determine the PR number (got '${pr}')" ;;
  esac
  sync_no_ticket "${pr}" "${final_title}" "${pr_marked}"
}

# sync_no_ticket <pr> <final title> <marked: true|false>: bring the PR to one
# rule, the no-ticket mark exactly when its final title names no ticket. The
# add is never folded into gh pr create, which fails whole on a label the repo
# lacks; a pushed, open bump must not fail over its mark, so a failed step only
# warns with the command that finishes it, and the next run on the branch
# retries. A --merge run merges at once, so it gets no retitle hint.
sync_no_ticket() {
  local pr="$1" final_title="$2" marked="$3" want=false
  ticket_titled "${final_title}" || want=true
  if [[ "${want}" = true ]] && [[ "${marked}" != true ]]
  then
    gh pr edit "${pr}" -R "${TAP_REPO}" --add-label "${NO_TICKET_LABEL}" >&2 ||
      say "bump.sh: warning: could not label PR #${pr} ${NO_TICKET_LABEL}; before any njord pr-merge, run: gh pr edit ${pr} -R ${TAP_REPO} --add-label ${NO_TICKET_LABEL}"
  elif [[ "${want}" != true ]] && [[ "${marked}" = true ]]
  then
    gh pr edit "${pr}" -R "${TAP_REPO}" --remove-label "${NO_TICKET_LABEL}" >&2 ||
      say "bump.sh: warning: could not remove ${NO_TICKET_LABEL} from PR #${pr}, whose title names a ticket; before any njord pr-merge, run: gh pr edit ${pr} -R ${TAP_REPO} --remove-label ${NO_TICKET_LABEL}"
  fi
  [[ "${want}" != true ]] || [[ "${merge}" = true ]] ||
    say "==> PR #${pr}'s title names no ticket. If a ticket covers this bump, retitle it and drop ${NO_TICKET_LABEL} in one command: gh pr edit ${pr} -R ${TAP_REPO} --title 'chore(STARK-<n>): bump ${entry} to ${tag}' --remove-label ${NO_TICKET_LABEL}"
}

# Whether title $1 names a ticket, as njord pr-merge reads it: TICKET_TITLE_RE
# against the title with its leading whitespace trimmed.
ticket_titled() {
  local t="$1"
  t="${t#"${t%%[![:space:]]*}"}"
  [[ ${t} =~ ${TICKET_TITLE_RE} ]]
}

# One reading of the gate's named checks for head $1: a line per workflow, then
# 0 all succeeded, 1 one concluded otherwise, 2 the runs are unreadable for want
# of Actions: read, 3 still pending (or a failed read, retried).
checks_verdict() {
  local out f status concl red=false pending=false
  # The newest pull_request run of each named workflow for this head.
  local newest='[.workflow_runs[] | select(.event == "pull_request")] as $r
    | ("'"${GATE_WORKFLOWS}"'" | split(" "))[] as $f
    | ([$r[] | select(.path == ".github/workflows/" + $f)] | max_by(.id)) as $x
    | "\($f) \($x.status // "missing") \($x.conclusion // "-")"'
  # stderr apart: a gh diagnostic (GH_DEBUG) must not parse as a workflow line.
  if ! out="$(gh api "repos/${TAP_REPO}/actions/runs?head_sha=$1&event=pull_request&per_page=100" --jq "${newest}" 2>"${tmp}/gh.err")"
  then
    out="${out}${out:+${NL}}$(<"${tmp}/gh.err")"
    printf '  %s\n' "${out}"
    case "${out}" in
      # A rate limit answers 403 too, and waiting may clear it.
      *"rate limit"*) ;;
      *"HTTP 403"*)
        printf '  %s\n' "reading ${TAP_REPO}'s workflow runs needs Actions: read on this token"
        return 2
        ;;
    esac
    return 3
  fi
  while read -r f status concl
  do
    [[ -n "${f}" ]] || continue
    printf '  %s: %s %s\n' "${f}" "${status}" "${concl}"
    if [[ "${status}" != completed ]]
    then
      pending=true
    elif [[ "${concl}" != success ]]
    then
      red=true
    fi
  done <<<"${out}"
  if ${red}; then return 1; fi
  if ${pending}; then return 3; fi
  return 0
}

# I14, Decision 4: merge only when every named workflow concluded success for the
# PR's exact head, pinned to that head.
merge_gate() {
  local polls=0 gated="" view state head mss runs rc reading="" shown="" out merge_shown=""
  local why="PR #${pr} is still not mergeable after ${POLL_BUDGET} polls"
  local fields='"\(.state) \(.headRefOid) \(.mergeStateStatus)"'
  while [[ "${polls}" -lt "${POLL_BUDGET}" ]]
  do
    polls=$((polls + 1))
    [[ "${polls}" -eq 1 ]] || pause
    # stderr apart: a gh diagnostic (GH_DEBUG) must not parse as the PR's fields.
    if ! view="$(gh pr view "${pr}" -R "${TAP_REPO}" --json state,headRefOid,mergeStateStatus --jq "${fields}" 2>"${tmp}/gh.err")"
    then
      reading="could not read PR #${pr}: $(<"${tmp}/gh.err")"
      continue
    fi
    read -r state head mss <<<"${view}"
    if [[ "${state}" = MERGED ]]
    then
      say "==> PR #${pr} is merged"
      return 0
    fi
    if [[ "${state}" = CLOSED ]]
    then
      why="PR #${pr} is closed"
      break
    fi
    # A reading just after a force-push can still name the branch's previous
    # head, whose runs are an older bump's: gate nothing until the PR shows the
    # commit this run pushed. Only then does a moved head restart the gate.
    if [[ -z "${gated}" ]] && [[ "${head}" != "${pushed}" ]]
    then
      reading="PR #${pr} still shows head ${head}, not the pushed ${pushed}"
      [[ "${reading}" = "${shown}" ]] || say "${reading}"
      shown="${reading}"
      continue
    fi
    if [[ -n "${gated}" ]] && [[ "${head}" != "${gated}" ]]
    then
      say "==> PR #${pr}'s head moved to ${head}: gating that head"
      # Decision 6: a head that is not the bumper's own commit holds a human's
      # edit, and that is never merged unattended.
      if ! bumper_shape "${head}" >/dev/null
      then
        why="PR #${pr}'s new head ${head} is not this bumper's own commit; not merging a human's edit unattended"
        break
      fi
    fi
    gated="${head}"
    if [[ "${mss}" = DIRTY ]]
    then
      why="PR #${pr} conflicts with main at ${head} (a newer bump of ${entry} may have landed)"
      break
    fi
    runs="$(checks_verdict "${gated}")" && rc=0 || rc=$?
    reading="PR #${pr} at ${gated} (${state}, ${mss}):${NL}${runs}"
    [[ "${reading}" = "${shown}" ]] || say "${reading}"
    shown="${reading}"
    if [[ "${rc}" -eq 1 ]]
    then
      why="a check PR #${pr} needs did not succeed"
      break
    fi
    if [[ "${rc}" -eq 2 ]]
    then
      why="the gate cannot read ${TAP_REPO}'s workflow runs without Actions: read on this token"
      break
    fi
    if [[ "${rc}" -eq 0 ]]
    then
      if out="$(gh pr merge "${pr}" -R "${TAP_REPO}" --squash --delete-branch --match-head-commit "${gated}" 2>&1)"
      then
        [[ -z "${out}" ]] || say "${out}"
        say "==> merged PR #${pr} at ${gated}"
        return 0
      fi
      # A moved head, or a merge that landed before its response was lost: the
      # next reading settles it. Say each new refusal now, not only at the end.
      reading="${reading}${NL}gh pr merge: ${out}"
      [[ "${out}" = "${merge_shown}" ]] || say "gh pr merge: ${out}"
      merge_shown="${out}"
    fi
  done
  # Decision 4: the last reading, replayed unsilenced.
  [[ -z "${reading}" ]] || say "${reading}"
  say "bump.sh: ${why}; not merging it"
  return 1
}

main() {
  local arg skip=false t
  # I12: help anywhere, outside an option's value and before --, does no work.
  for arg in "$@"
  do
    if ${skip}
    then
      skip=false
      continue
    fi
    case "${arg}" in
      --) break ;;
      --ticket | --asset-suffix) skip=true ;;
      help | -h | --help)
        usage
        exit 0
        ;;
    esac
  done
  trap cleanup EXIT

  while [[ $# -gt 0 ]]
  do
    case "$1" in
      --)
        shift
        while [[ $# -gt 0 ]]
        do
          take_positional "$1"
          shift
        done
        break
        ;;
      --ticket | --asset-suffix)
        [[ $# -ge 2 ]] || usage_error "$1 needs a value"
        if [[ "$1" = --ticket ]]; then ticket="$2"; else suffix="$2"; fi
        shift
        ;;
      --dry-run) dry_run=true ;;
      --no-pr) no_pr=true ;;
      --merge) merge=true ;;
      -*) usage_error "unknown flag: $1" ;;
      *) take_positional "$1" ;;
    esac
    shift
  done

  [[ "${npos}" -eq 2 ]] || usage_error "expected <entry> <tag>"
  [[ ${entry} =~ ${ENTRY_RE} ]] || usage_error "invalid entry name: ${entry}"
  [[ ${tag} =~ ${TAG_RE} ]] || usage_error "invalid tag ${tag}: want X.Y.Z[-pre] after an optional prefix (v1.2.3, cli-v1.2.3)"
  version="${BASH_REMATCH[2]}"
  [[ -z "${ticket}" ]] || [[ ${ticket} =~ ^STARK-[0-9]+$ ]] || usage_error "invalid --ticket ${ticket}: want STARK-<n>"
  [[ ${suffix} =~ ^[A-Za-z0-9._-]+$ ]] || usage_error "invalid --asset-suffix ${suffix}"
  if ${merge} && { ${dry_run} || ${no_pr}; }; then usage_error "--merge opens and merges a PR; it cannot go with --dry-run or --no-pr"; fi
  [[ ${POLL_BUDGET} =~ ^[0-9]+$ && ${POLL_SECONDS} =~ ^[0-9]+$ ]] || usage_error "BUMP_POLL_BUDGET and BUMP_POLL_SECONDS must be whole numbers"

  case "${BASH_SOURCE[0]}" in
    */*) tap_root="${BASH_SOURCE[0]%/*}/.." ;;
    *) tap_root=.. ;;
  esac
  # CDPATH off: a relative scripts/.. must resolve against the working directory.
  tap_root="$(CDPATH='' cd -- "${tap_root}" && pwd -P)"
  # A cask can also sit in a folder of Casks/ named for its first character, as
  # homebrew/cask shards its casks (Casks/i/idavoll.rb): Homebrew reads
  # Casks/**/*.rb. The idavoll cask is there so that idavoll's Fleet CLIs step,
  # which reads Casks/*.rb, never installs it.
  local found=0 cand shard="Casks/${entry:0:1}/${entry}.rb"
  for cand in "Formula/${entry}.rb" "Casks/${entry}.rb" "${shard}"
  do
    if [[ -f "${tap_root}/${cand}" ]]
    then
      rel="${cand}"
      found=$((found + 1))
    fi
  done
  [[ "${found}" -ne 0 ]] || die "no tap entry ${entry}: none of Formula/${entry}.rb, Casks/${entry}.rb and ${shard} exists in ${tap_root}"
  [[ "${found}" -eq 1 ]] || die "${entry} is ambiguous: more than one of Formula/${entry}.rb, Casks/${entry}.rb and ${shard} exists"
  read_entry

  for t in gh git perl
  do
    command -v "${t}" >/dev/null || die "${t} is not on PATH"
  done
  command -v sha256sum >/dev/null || command -v shasum >/dev/null || die "neither sha256sum nor shasum is on PATH"
  tmp="$(perl -MFile::Temp=tempdir -e 'print tempdir("bump.XXXXXX", TMPDIR => 1)')" ||
    die "could not create a temporary directory"

  local pr_run=true
  if ${dry_run} || ${no_pr}; then pr_run=false; fi
  if ${pr_run}; then check_checkout; fi

  resolve_asset
  if ${public}
  then
    [[ ${a_name} =~ ${ASSET_NAME_RE} ]] || die "unexpected asset name for a public release: ${a_name}"
    pub_tag="${entry}-v${version}"
    pub_url="https://github.com/${TAP_REPO}/releases/download/${pub_tag}/${a_name}"
    check_source_files
  fi
  rewrite_entry "${tmp}/updated" || die "not rewriting ${rel}"
  if git diff --no-index --quiet -- "${tap_root}/${rel}" "${tmp}/updated"
  then
    # A pinned public entry's release must exist; a dry run only says so.
    if ${public} && ! ${dry_run}; then publish_asset; fi
    say "==> ${rel} already pins ${repo} ${tag}; nothing to do"
    return 0
  fi
  say "==> ${rel}:"
  git --no-pager diff --no-index --no-ext-diff --no-color -- "${tap_root}/${rel}" "${tmp}/updated" >&2 || true
  if ${dry_run}
  then
    ! ${public} || say "==> --dry-run: would publish ${a_name} as the release ${pub_tag} of ${TAP_REPO}"
    say "==> --dry-run: changed nothing"
    return 0
  fi
  if ${pr_run} && [[ ${pinned} =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]] && core_older "${version}" "${pinned}"
  then
    say "==> ${rel} pins ${pinned}, newer than ${version}: a PR run never moves an entry back (stage it with --no-pr)"
    return 0
  fi
  if ${public}; then publish_asset; fi
  if ${no_pr}
  then
    copy_file "${tmp}/updated" "${tap_root}/${rel}" || die "could not write ${rel}"
    say "==> --no-pr: edited ${tap_root}/${rel} (not committed)"
    return 0
  fi

  publish_pr
  printf '%s\n' "${pr}"
  if ${merge}; then merge_gate; fi
}

# Parsed whole before main runs, so bash never reads a line of this file after
# the run starts (I15).
if [[ "${BASH_SOURCE[0]}" = "$0" ]]
then
  main "$@"
  exit
fi
