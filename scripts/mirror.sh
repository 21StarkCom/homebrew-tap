#!/usr/bin/env bash
# scripts/mirror.sh: copies the entries of this tap, with their release assets,
# into GetEvinced/homebrew-tap, so an Evinced engineer installs them with no
# access to 21StarkCom. The design is docs/specs/getevinced-mirror.md (epic
# STARK-13601); `scripts/mirror.sh --help` is the reference. Tests:
# scripts/test-mirror.sh. .github/workflows/mirror.yml runs it on each push to main.
#
# brew style (formulae.yml) lints this with every optional shellcheck check. Off:
# single-quoted $names are jq's and perl's, not the shell's (SC2016); functions
# run from conditions return their own status on purpose (SC2310); a case with no
# match has nothing to do (SC2249).
# shellcheck disable=SC2016,SC2249,SC2310
set -euo pipefail

# 4.4: older bash aborts on an empty "${array[@]}" under set -u.
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4)))
then
  echo "mirror.sh: needs bash 4.4 or later, not ${BASH_VERSION}. On a Mac, run it with Homebrew's bash." >&2
  exit 2
fi

TARGET_REPO="GetEvinced/homebrew-tap"
TARGET_URL="https://github.com/${TARGET_REPO}.git"
# Entries that never reach GetEvinced: their assets hold the operator's source
# or readable JS (the atlas repo's atlas, brain and librarian; lucius; odinctl).
# The operator's decision of 2026-10-28 (spec D11). A marked copy of one is deleted.
EXCLUDED="atlas brain librarian lucius odinctl"
MARKER='# Mirrored from 21StarkCom/homebrew-tap by scripts/mirror.sh. Do not edit: the next run overwrites it.'
FROZEN='# frozen_string_literal: true'
BEGIN_MARK='<!-- BEGIN 21stark-mirror -->'
END_MARK='<!-- END 21stark-mirror -->'
PUSH_TRIES=3
# An upload that is not "uploaded" this long after its last update is a dead run's.
STALE_UPLOAD_SECONDS=3600
# The bumper's URL_RE (scripts/bump.sh), with the asset id captured too.
URL_RE='^[[:space:]]*url[[:space:]]+"https://api\.github\.com/repos/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/releases/assets/([0-9]+)"'
VERSION_RE='^[[:space:]]*version[[:space:]]+"([^"]+)"'
SHA_RE='^[[:space:]]*sha256[[:space:]]+"([0-9a-f]{64})"'
HOMEPAGE_RE='^[[:space:]]*homepage[[:space:]]+"([^"]+)"'
ENTRY_RE='^[A-Za-z0-9][A-Za-z0-9@+._-]*$'
NL=$'\n'

dry_run=false branch=main
declare -a only=() names=() changed_formulae=() changed_casks=()
declare -A kind=() rel=() src_repo=() src_id=() ver=() sha=() new_id=() failed=() wanted=() excluded=()
tmp="" clone="" src_root="" src_rev="" created_branch=false auth_header=""
changed="" pushed=false rejected=false attempt=0

usage() {
  cat <<'EOF'
Usage: scripts/mirror.sh [--dry-run] [--branch <name>] [--only <entry>]...

Make a branch of GetEvinced/homebrew-tap match the entries of this checkout:
each entry's release asset is copied into a GetEvinced release, and each entry
is written there with its asset URL pointed at that copy
(docs/specs/getevinced-mirror.md). atlas, brain, librarian, lucius and odinctl
are never copied: their assets hold source or readable JS.

  --branch <name>   the GetEvinced branch to push (default main); made from
                    main when it does not exist
  --only <entry>    copy only this entry (repeatable), and delete no file
  --dry-run         print the plan; upload, delete, commit and push nothing
  -h, --help        this text

Run it from a checkout whose Formula/ and Casks/ have no uncommitted change.
To push main, HEAD must be origin/main (git fetch first).

Environment:
  MIRROR_SOURCE_TOKEN  reads the 21StarkCom release assets (not needed for --dry-run)
  MIRROR_TARGET_TOKEN  reads and writes GetEvinced/homebrew-tap: releases and the branch
  MIRROR_GIT_NAME, MIRROR_GIT_EMAIL
                       the commit's author and committer (default: git's own)
  GITHUB_OUTPUT        when set, gets formulae=, casks= (the changed entries) and pushed=

For each entry, in this order: find the release <entry>-v<version> and its asset
whose digest is the pinned sha256; else download the source asset, check it,
make the release as a draft, upload, and publish it. Then write the entry with
the marker line, the copy's asset URL, 21starkcom/tap renamed to getevinced/tap,
and "21StarkCom private repos" renamed. Then delete marked files whose entry left
this tap, moved, or is excluded; rewrite the README block; commit once and push.
A push that loses a race clones again and writes again, up to three times. Files
without the marker line (aac, evinced) are never changed. No release and no
uploaded asset is ever deleted; an upload a dead run left (an hour old) is.

Exit: 0 every entry copied; 1 an entry failed (the others still pushed) or the
run failed; 2 usage. Needs bash 4.4+, git, gh, jq, perl and sha256sum or shasum.
EOF
}

say() { printf '%s\n' "$*"; }
warn() { printf 'mirror.sh: %s\n' "$*" >&2; }
die() {
  warn "$*"
  exit 1
}
usage_error() {
  warn "$*"
  echo "Run scripts/mirror.sh --help for usage." >&2
  exit 2
}
# MIRROR_KEEP_TMP=1 keeps the work directory, for scripts/test-mirror.sh to search.
cleanup() { [[ -z ${tmp} || -n ${MIRROR_KEEP_TMP:-} ]] || rm -rf "${tmp}"; }

hash_of() {
  local out
  if command -v sha256sum >/dev/null 2>&1
  then
    out="$(sha256sum "$1")"
  else
    out="$(shasum -a 256 "$1")"
  fi
  printf '%s\n' "${out%% *}"
}

# gh as each side: the token goes in the environment, never in an argument.
src_gh() { GH_TOKEN="${MIRROR_SOURCE_TOKEN}" gh "$@"; }
dst_gh() { GH_TOKEN="${MIRROR_TARGET_TOKEN}" gh "$@"; }
# git toward GetEvinced: the token rides an http.extraheader in the environment,
# so it never lands in .git/config, a URL or an argument.
tgit() {
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
    GIT_CONFIG_VALUE_0="${auth_header}" GIT_TERMINAL_PROMPT=0 git "$@"
}
cgit() {
  local -a who=()
  [[ -z ${MIRROR_GIT_NAME:-} ]] || who+=(-c "user.name=${MIRROR_GIT_NAME}")
  [[ -z ${MIRROR_GIT_EMAIL:-} ]] || who+=(-c "user.email=${MIRROR_GIT_EMAIL}")
  tgit -C "${clone}" "${who[@]}" "$@"
}

fail_entry() { # <entry> <reason>
  failed[$1]="$2"
  warn "$1: $2"
}

parse_args() {
  while (($# > 0))
  do
    case "$1" in
      -h | --help | help)
        usage
        exit 0
        ;;
      --dry-run) dry_run=true ;;
      --branch)
        [[ $# -ge 2 && -n $2 ]] || usage_error "--branch needs a name"
        branch="$2"
        shift
        ;;
      --only)
        [[ $# -ge 2 && $2 =~ ${ENTRY_RE} ]] || usage_error "--only needs an entry name"
        only+=("$2")
        shift
        ;;
      *) usage_error "unknown argument: $1" ;;
    esac
    shift
  done
  [[ ${branch} =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || usage_error "bad branch name: ${branch}"
}

# The copy is of what this checkout holds, so it must hold what main holds.
check_source() {
  local dirty head main
  ${dry_run} && return 0
  dirty="$(git -C "${src_root}" status --porcelain -- Formula Casks)" ||
    usage_error "${src_root} is not a git checkout"
  [[ -z ${dirty} ]] || usage_error "Formula/ or Casks/ has uncommitted changes:${NL}${dirty}"
  [[ ${branch} == main ]] || return 0
  head="$(git -C "${src_root}" rev-parse HEAD)"
  main="$(git -C "${src_root}" rev-parse -q --verify refs/remotes/origin/main)" ||
    usage_error "no origin/main in ${src_root}: git fetch origin main first"
  [[ ${head} == "${main}" ]] ||
    usage_error "HEAD ${head:0:7} is not origin/main ${main:0:7}: copy main only from a checkout of it (git fetch first)"
}

# Reads every Formula/ and Casks/ entry of this checkout into the arrays.
read_entries() {
  local f name line first n_url n_ver n_sha e
  for e in ${EXCLUDED}; do excluded[${e}]=1; done
  for f in "${src_root}"/Formula/*.rb "${src_root}"/Casks/*.rb
  do
    [[ -f ${f} ]] || continue
    name="${f##*/}"
    name="${name%.rb}"
    if [[ -n ${excluded[${name}]:-} ]]
    then
      say "${name}: excluded; not copied"
      continue
    fi
    if [[ -n ${kind[${name}]:-} ]]
    then
      # Homebrew keeps formula and cask names apart; the copy keys by name.
      fail_entry "${name}" "is both ${rel[${name}]} and ${f#"${src_root}"/}; the mirror copies neither"
      continue
    fi
    names+=("${name}")
    if [[ ${f} == */Casks/* ]]; then kind[${name}]=cask; else kind[${name}]=formula; fi
    rel[${name}]="${f#"${src_root}"/}"
    first="" n_url=0 n_ver=0 n_sha=0
    while IFS= read -r line || [[ -n ${line} ]]
    do
      [[ -n ${first} ]] || first="${line:-<blank>}"
      if [[ ${line} =~ ${URL_RE} ]]
      then
        n_url=$((n_url + 1))
        src_repo[${name}]="${BASH_REMATCH[1]}"
        src_id[${name}]="${BASH_REMATCH[2]}"
      elif [[ ${line} =~ ${VERSION_RE} ]]
      then
        n_ver=$((n_ver + 1))
        ver[${name}]="${BASH_REMATCH[1]}"
      elif [[ ${line} =~ ${SHA_RE} ]]
      then
        n_sha=$((n_sha + 1))
        sha[${name}]="${BASH_REMATCH[1]}"
      fi
    done <"${f}"
    if [[ ${first} != "${FROZEN}" ]]
    then
      fail_entry "${name}" "its first line is not '${FROZEN}'"
    elif ((n_url != 1 || n_ver != 1 || n_sha != 1))
    then
      fail_entry "${name}" "needs one url, version and sha256 stanza each; has ${n_url}, ${n_ver} and ${n_sha}"
    fi
    # The copy renames 21StarkCom/tap/<x> to GetEvinced/tap/<x>, which does not
    # exist for an excluded x: such an entry stays out until it is excluded too.
    for e in ${EXCLUDED}
    do
      if grep -qiE "21starkcom/tap/${e}([^A-Za-z0-9_-]|\$)" "${f}"
      then
        fail_entry "${name}" "it names 21StarkCom/tap/${e}, which the mirror excludes; exclude ${name} too, or drop the reference"
        break
      fi
    done
  done
  ((${#names[@]} > 0)) || die "no entry to copy in ${src_root}"
  local o
  for o in "${only[@]}"
  do
    [[ -z ${excluded[${o}]:-} ]] || usage_error "--only ${o}: it is excluded from the mirror"
    [[ -n ${kind[${o}]:-} ]] || usage_error "--only ${o}: no such entry in this tap"
    wanted[${o}]=1
  done
}

selected() { ((${#only[@]} == 0)) || [[ -n ${wanted[$1]:-} ]]; }
active() { selected "$1" && [[ -z ${failed[$1]:-} ]]; }

# Clones the GetEvinced branch into $clone, from main when the branch is new.
clone_target() {
  local rc=0
  rm -rf "${clone}"
  tgit ls-remote --exit-code --heads "${TARGET_URL}" "refs/heads/${branch}" >/dev/null 2>&1 || rc=$?
  case "${rc}" in
    0) created_branch=false ;;
    2)
      [[ ${branch} != main ]] || die "${TARGET_REPO} has no main branch"
      created_branch=true
      ;;
    *) die "cannot read ${TARGET_REPO} (git ls-remote exit ${rc}): check MIRROR_TARGET_TOKEN" ;;
  esac
  if ${created_branch}
  then
    tgit clone -q --depth 1 --branch main "${TARGET_URL}" "${clone}" || die "cannot clone ${TARGET_REPO}"
  else
    tgit clone -q --depth 1 --branch "${branch}" "${TARGET_URL}" "${clone}" || die "cannot clone ${TARGET_REPO} ${branch}"
  fi
}

marked() { [[ -f $1 ]] && grep -qxF -- "${MARKER}" "$1"; }

# Fails each entry whose GetEvinced file exists without the marker line.
check_clashes() {
  local name
  for name in "${names[@]}"
  do
    active "${name}" || continue
    if [[ -e "${clone}/${rel[${name}]}" ]] && ! marked "${clone}/${rel[${name}]}"
    then
      fail_entry "${name}" "${TARGET_REPO} has ${rel[${name}]} without the mirror marker; it is not ours to overwrite"
    fi
  done
}

list_releases() {
  dst_gh api --paginate "repos/${TARGET_REPO}/releases?per_page=100" >"${tmp}/releases.json" ||
    die "cannot list the releases of ${TARGET_REPO}"
  jq -c '.[] | {id, tag: .tag_name, draft, assets: [.assets[] | {id, name, state, digest, updated_at}]}' \
    "${tmp}/releases.json" >"${tmp}/releases.jsonl"
}

# Sets $release to the one release tagged $1, as a JSON line, or to "" when none
# has the tag. Returns 1 when more than one has it: an upload by tag could then
# land in another release than the one read back.
find_release() {
  local n
  n="$(jq -s --arg t "$1" '[.[] | select(.tag == $t)] | length' "${tmp}/releases.jsonl")"
  ((n <= 1)) || return 1
  release="$(jq -sc --arg t "$1" '[.[] | select(.tag == $t)][0] // empty' "${tmp}/releases.jsonl")"
  [[ -z ${release} ]] || return 0
  # Not in the listing (made since, or a page short): ask for the tag itself.
  release="$(dst_gh api "repos/${TARGET_REPO}/releases/tags/$1" 2>/dev/null |
    jq -c '{id, tag: .tag_name, draft, assets: [.assets[] | {id, name, state, digest, updated_at}]}' 2>/dev/null)" ||
    release=""
  return 0
}

publish_release() { # <entry> <release id> <tag>
  dst_gh api -X PATCH "repos/${TARGET_REPO}/releases/$2" -F draft=false -f make_latest=false >/dev/null || {
    fail_entry "$1" "cannot publish the release $3"
    return 1
  }
}

# Sets new_id[$1] to a GetEvinced asset with the entry's bytes: an uploaded copy
# found by its digest, or one this run uploads. Fails the entry on any error.
ensure_asset() {
  local name="$1" tag release="" rjson rid draft found sname file got uname taken asset state digest busy
  tag="${name}-v${ver[${name}]}"
  find_release "${tag}" || {
    fail_entry "${name}" "${TARGET_REPO} has more than one release tagged ${tag}; delete the extra one"
    return 0
  }
  if [[ -n ${release} ]]
  then
    rid="$(jq -r .id <<<"${release}")"
    draft="$(jq -r .draft <<<"${release}")"
    found="$(jq -r --arg d "sha256:${sha[${name}]}" \
      '[.assets[] | select(.state == "uploaded" and .digest == $d)][0].id // empty' <<<"${release}")"
    if [[ -n ${found} ]]
    then
      # A draft here holds the asset of a run that stopped before publishing.
      if [[ ${draft} == true ]] && ! ${dry_run}
      then
        publish_release "${name}" "${rid}" "${tag}" || return 0
      fi
      new_id[${name}]="${found}"
      say "${name} ${ver[${name}]}: reuse asset ${found} of release ${tag}"
      return 0
    fi
  fi
  if ${dry_run}
  then
    # A stand-in id, so the plan shows the file this copy would change.
    new_id[${name}]=0
    say "${name} ${ver[${name}]}: would copy ${src_repo[${name}]} asset ${src_id[${name}]} to release ${tag}"
    return 0
  fi

  # An upload still in progress may be another run's; one an hour old is dead.
  busy="$(jq -r --argjson age "${STALE_UPLOAD_SECONDS}" \
    '[.assets[] | select(.state != "uploaded" and (now - (.updated_at | fromdateiso8601)) < $age)][0].id // empty' \
    <<<"${release:-"{}"}" 2>/dev/null)" || busy=""
  if [[ -n ${busy} ]]
  then
    fail_entry "${name}" "an upload to ${tag} is in progress (asset ${busy}); the next run retries"
    return 0
  fi

  sname="$(src_gh api "repos/${src_repo[${name}]}/releases/assets/${src_id[${name}]}" --jq .name)" || {
    fail_entry "${name}" "cannot read ${src_repo[${name}]} asset ${src_id[${name}]}"
    return 0
  }
  [[ ${sname} =~ ^[A-Za-z0-9._+@-]+$ ]] || {
    fail_entry "${name}" "unexpected source asset name: ${sname}"
    return 0
  }
  rm -rf "${tmp}/up"
  mkdir -p "${tmp}/up"
  file="${tmp}/up/${sname}"
  say "${name} ${ver[${name}]}: downloading ${src_repo[${name}]} asset ${src_id[${name}]} (${sname})"
  if ! src_gh api -H 'Accept: application/octet-stream' "repos/${src_repo[${name}]}/releases/assets/${src_id[${name}]}" >"${file}"
  then
    fail_entry "${name}" "cannot download ${src_repo[${name}]} asset ${src_id[${name}]}"
    return 0
  fi
  got="$(hash_of "${file}")"
  if [[ ${got} != "${sha[${name}]}" ]]
  then
    fail_entry "${name}" "${src_repo[${name}]} asset ${src_id[${name}]} does not match the pinned sha256 ${sha[${name}]}"
    rm -f "${file}"
    return 0
  fi

  if [[ -z ${release} ]]
  then
    rid="$(dst_gh api -X POST "repos/${TARGET_REPO}/releases" -f tag_name="${tag}" -f target_commitish=main \
      -f name="${name} ${ver[${name}]}" -F draft=true -f make_latest=false \
      -f body="A copy of ${src_repo[${name}]} release asset ${src_id[${name}]} (\`${sname}\`), SHA-256 \`${sha[${name}]}\`, made by scripts/mirror.sh of 21StarkCom/homebrew-tap for its GetEvinced/tap entry \`${name}\`." \
      --jq .id)" || {
      fail_entry "${name}" "cannot create the release ${tag}"
      return 0
    }
    draft=true
  else
    # A dead run's incomplete upload; no entry can pin it.
    for asset in $(jq -r '.assets[] | select(.state != "uploaded") | .id' <<<"${release}")
    do
      dst_gh api -X DELETE "repos/${TARGET_REPO}/releases/assets/${asset}" >/dev/null || {
        fail_entry "${name}" "cannot delete the incomplete upload ${asset} of ${tag}"
        return 0
      }
    done
  fi

  uname="${sname}"
  rjson="${release}"
  [[ -n ${rjson} ]] || rjson='{"assets":[]}'
  taken="$(jq -r --arg n "${sname}" '[.assets[] | select(.state == "uploaded" and .name == $n)] | length' <<<"${rjson}")"
  if [[ ${taken} != 0 ]]
  then
    # Other bytes under this version: keep them (an entry may pin them) and name ours apart.
    uname="${sha[${name}]:0:12}-${sname}"
    mv "${file}" "${tmp}/up/${uname}"
    file="${tmp}/up/${uname}"
  fi
  say "${name} ${ver[${name}]}: uploading ${uname} to release ${tag}"
  if ! dst_gh release upload "${tag}" "${file}" -R "${TARGET_REPO}" >/dev/null
  then
    fail_entry "${name}" "cannot upload ${uname} to ${tag}"
    rm -f "${file}"
    return 0
  fi
  rm -f "${file}"
  asset="$(dst_gh api "repos/${TARGET_REPO}/releases/${rid}" |
    jq -c --arg n "${uname}" '[.assets[] | select(.name == $n)][0] // empty')" || asset=""
  [[ -n ${asset} ]] || asset='{}'
  state="$(jq -r '.state // empty' <<<"${asset}")"
  digest="$(jq -r '.digest // empty' <<<"${asset}")"
  if [[ ${state} != uploaded ]] || [[ -n ${digest} && ${digest} != "sha256:${sha[${name}]}" ]]
  then
    fail_entry "${name}" "the upload of ${uname} to ${tag} reads back as state '${state}', digest '${digest}'"
    return 0
  fi
  if [[ ${draft} == true ]]
  then
    publish_release "${name}" "${rid}" "${tag}" || return 0
  fi
  new_id[${name}]="$(jq -r .id <<<"${asset}")"
  say "${name} ${ver[${name}]}: uploaded asset ${new_id[${name}]}"
}

# Writes the copy of entry $1 into the clone (the spec's "The copy of an entry").
write_copy() {
  local name="$1" out
  out="$(TARGET_REPO="${TARGET_REPO}" NEWID="${new_id[${name}]}" MARKER="${MARKER}" FROZEN="${FROZEN}" perl -0777 -ne '
    my $first = "$ENV{FROZEN}\n";
    substr($_, 0, length $first) eq $first or die "its first line is not $ENV{FROZEN}\n";
    my $rest = substr($_, length $first);
    $rest =~ s/\A\n//;
    my $url = qr{^([ \t]*url[ \t]+"https://api\.github\.com/repos/)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/releases/assets/)[0-9]+"}m;
    my $n = 0;
    $n++ while $rest =~ /$url/g;
    $n == 1 or die "it has $n asset url stanzas\n";
    $rest =~ s/$url/$1$ENV{TARGET_REPO}$2$ENV{NEWID}"/;
    $rest =~ s{(21starkcom)(/tap)\b}{($1 eq lc($1) ? "getevinced" : "GetEvinced") . $2}gie;
    $rest =~ s{read access to 21StarkCom private repos}{read access to GetEvinced private repos}g;
    $rest =~ m{21starkcom/tap\b}i and die "the copy still names 21starkcom/tap\n";
    print $first, "\n", $ENV{MARKER}, "\n\n", $rest;
  ' "${src_root}/${rel[${name}]}" 2>"${tmp}/perl.err")" || {
    fail_entry "${name}" "cannot copy ${rel[${name}]}: $(<"${tmp}/perl.err")"
    return 0
  }
  mkdir -p "${clone}/${rel[${name}]%/*}"
  printf '%s\n' "${out}" >"${clone}/${rel[${name}]}"
}

# Deletes each marked GetEvinced file whose entry left this tap, moved between
# Formula/ and Casks/, or is excluded.
remove_departed() {
  local f name path why
  for f in "${clone}"/Formula/*.rb "${clone}"/Casks/*.rb
  do
    marked "${f}" || continue
    name="${f##*/}"
    name="${name%.rb}"
    path="${f#"${clone}"/}"
    if [[ -n ${excluded[${name}]:-} ]]
    then
      why="is excluded from the mirror"
    elif [[ -z ${kind[${name}]:-} ]]
    then
      why="left 21StarkCom/homebrew-tap"
    elif [[ ${rel[${name}]} != "${path}" ]]
    then
      why="moved to ${rel[${name}]}"
    else
      continue
    fi
    say "${name}: ${why}; deleting ${path} (its releases stay)"
    rm -f "${f}"
  done
}

# Rewrites the README block from the marked files in the clone.
write_readme() {
  local block f name k v home line sep=""
  block="${BEGIN_MARK}
## Mirrored from 21StarkCom/homebrew-tap

The mirror job of \`21StarkCom/homebrew-tap\` (its \`scripts/mirror.sh\`) writes this
section and every file that holds its marker line. A change made here is lost at
its next run. Each of these entries downloads its asset from a release of this
repo, so installing needs read access to this repo only.

\`\`\`sh
brew tap GetEvinced/tap
brew trust --tap GetEvinced/tap
brew install GetEvinced/tap/<entry>
brew install --cask GetEvinced/tap/<cask>
\`\`\`

Homebrew needs a GitHub token that can read this repo: Homebrew's own \`gh\`
(\`brew install gh\`, then \`gh auth login\`), or \`HOMEBREW_GITHUB_API_TOKEN\`. A Mac
that also taps \`21StarkCom/tap\` must use full names in every \`brew\` command,
\`brew services\` included, for example \`GetEvinced/tap/idun\`.

| Entry | Kind | Version | Source |
|---|---|---|---|"
  for f in "${clone}"/Formula/*.rb "${clone}"/Casks/*.rb
  do
    marked "${f}" || continue
    name="${f##*/}"
    name="${name%.rb}"
    if [[ ${f} == */Casks/* ]]; then k=cask; else k=formula; fi
    v="" home=""
    while IFS= read -r line
    do
      if [[ -z ${v} && ${line} =~ ${VERSION_RE} ]]; then v="${BASH_REMATCH[1]}"; fi
      if [[ -z ${home} && ${line} =~ ${HOMEPAGE_RE} ]]; then home="${BASH_REMATCH[1]}"; fi
    done <"${f}"
    block+="${NL}| \`${name}\` | ${k} | ${v} | [${home#https://github.com/}](${home}) |"
  done
  block+="${NL}${END_MARK}"
  if [[ -f "${clone}/README.md" ]] && grep -qxF -- "${BEGIN_MARK}" "${clone}/README.md" &&
     grep -qxF -- "${END_MARK}" "${clone}/README.md"
  then
    # The END line may be the file's last, with no newline after it.
    BLOCK="${block}" BEGIN_MARK="${BEGIN_MARK}" END_MARK="${END_MARK}" perl -0777 -pi -e '
      s/^\Q$ENV{BEGIN_MARK}\E\n.*?^\Q$ENV{END_MARK}\E(?:\n|\z)/$ENV{BLOCK}\n/ms
    ' "${clone}/README.md" || die "cannot rewrite the README block"
  else
    [[ ! -s "${clone}/README.md" ]] || sep="${NL}"
    printf '%s%s\n' "${sep}" "${block}" >>"${clone}/README.md"
  fi
}

# Writes every copy, deletes departed files and the README block; commits and
# pushes. Sets rejected=true when the push lost a race. main runs it as a plain
# command, so set -e holds inside it.
write_and_push() {
  local name path head
  local -a was_formulae=("${changed_formulae[@]}") was_casks=("${changed_casks[@]}")
  attempt=$((attempt + 1))
  rejected=false
  for name in "${names[@]}"
  do
    active "${name}" || continue
    [[ -n ${new_id[${name}]:-} ]] || continue
    write_copy "${name}"
  done
  ((${#only[@]} > 0)) || remove_departed
  write_readme
  cgit add -A
  cgit diff --cached --name-only >"${tmp}/changed"
  changed_formulae=() changed_casks=() changed=""
  while IFS= read -r path
  do
    [[ ${path} == *.rb ]] || continue
    name="${path##*/}"
    name="${name%.rb}"
    if [[ ! -e "${clone}/${path}" ]]
    then
      changed+="${NL}- ${name}: deleted from ${path}"
      continue
    fi
    case "${path}" in
      Formula/*) changed_formulae+=("${name}") ;;
      Casks/*) changed_casks+=("${name}") ;;
    esac
    changed+="${NL}- ${name} ${ver[${name}]:-}"
  done <"${tmp}/changed"

  if cgit diff --cached --quiet
  then
    if ((attempt > 1))
    then
      # The earlier push landed (its reply was lost) or a twin run pushed the same
      # files: GetEvinced holds them, so report them as this run's.
      changed_formulae=("${was_formulae[@]}") changed_casks=("${was_casks[@]}")
      pushed=true
      say "${TARGET_REPO} ${branch}: already holds this copy"
      return 0
    fi
    say "${TARGET_REPO} ${branch}: no change"
    ${created_branch} || return 0
  elif ${dry_run}
  then
    say "dry run: would commit and push to ${TARGET_REPO} ${branch}:"
    cgit diff --cached --stat >"${tmp}/stat"
    sed 's/^/  /' "${tmp}/stat"
    return 0
  else
    cgit commit -q -m "mirror: 21StarkCom/homebrew-tap@${src_rev}" \
      -m "Copied by scripts/mirror.sh (docs/specs/getevinced-mirror.md).${changed:+${NL}${changed}}"
  fi
  ${dry_run} && return 0
  head="$(cgit rev-parse --short HEAD)"
  if cgit push -q origin "HEAD:refs/heads/${branch}" 2>"${tmp}/push.err"
  then
    pushed=true
    say "${TARGET_REPO} ${branch}: pushed ${head}"
  elif grep -qE '\[rejected\].*\((fetch first|non-fast-forward)\)' "${tmp}/push.err"
  then
    rejected=true
  else
    # A ruleset, permission or network refusal: a retry would meet it again.
    die "${TARGET_REPO} refused the push:${NL}$(<"${tmp}/push.err")"
  fi
}

main() {
  parse_args "$@"
  local tool
  for tool in git gh jq perl
  do
    command -v "${tool}" >/dev/null || die "${tool} is required"
  done
  command -v sha256sum >/dev/null || command -v shasum >/dev/null || die "sha256sum or shasum is required"
  [[ -n ${MIRROR_TARGET_TOKEN:-} ]] || usage_error "MIRROR_TARGET_TOKEN is not set"
  ${dry_run} || [[ -n ${MIRROR_SOURCE_TOKEN:-} ]] || usage_error "MIRROR_SOURCE_TOKEN is not set"
  auth_header="AUTHORIZATION: basic $(printf 'x-access-token:%s' "${MIRROR_TARGET_TOKEN}" | base64 | tr -d '\n')"

  src_root="$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
  check_source
  src_rev="$(git -C "${src_root}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/mirror.XXXXXX")"
  trap cleanup EXIT
  clone="${tmp}/target"

  read_entries
  clone_target
  check_clashes
  list_releases

  local name
  for name in "${names[@]}"
  do
    active "${name}" || continue
    ensure_asset "${name}"
  done

  while :
  do
    write_and_push
    ${rejected} || break
    ((attempt < PUSH_TRIES)) || die "${TARGET_REPO} rejected the push ${PUSH_TRIES} times"
    warn "${TARGET_REPO} rejected the push; cloning again (try $((attempt + 1)) of ${PUSH_TRIES})"
    clone_target
    check_clashes
  done

  if [[ -n ${GITHUB_OUTPUT:-} ]]
  then
    {
      echo "formulae=${changed_formulae[*]}"
      echo "casks=${changed_casks[*]}"
      echo "pushed=${pushed}"
    } >>"${GITHUB_OUTPUT}"
  fi

  local n_failed=0
  for name in "${!failed[@]}"
  do
    selected "${name}" || continue
    n_failed=$((n_failed + 1))
    warn "FAILED ${name}: ${failed[${name}]}"
  done
  if ${dry_run}
  then
    ((n_failed == 0)) || die "dry run: ${n_failed} entry(ies) would fail"
    say "dry run: no entry fails; nothing was written"
    return 0
  fi
  ((n_failed == 0)) || die "${n_failed} entry(ies) failed; the others are copied"
  say "done: every entry is copied"
}

main "$@"
