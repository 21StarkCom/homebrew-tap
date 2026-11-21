#!/usr/bin/env bash
# scripts/mirror.sh: copies the entries of this tap, with their release assets,
# into another tap. The default target is GetEvinced/homebrew-tap, so an Evinced
# engineer installs them with no access to 21StarkCom (docs/specs/getevinced-mirror.md,
# epic STARK-13601). --target public copies the entries of PUBLIC_ENTRIES into
# 21StarkCom/homebrew-public, which anyone installs from with no GitHub login
# (docs/specs/public-tap.md, STARK-19531). `scripts/mirror.sh --help` is the
# reference. Tests: scripts/test-mirror.sh. .github/workflows/mirror.yml runs it
# on each push to main.
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

# Set by set_target from --target: getevinced (the default) or public.
TARGET_REPO="" TARGET_URL="" TARGET_TAP="" TARGET_SPEC=""
PUBLIC_REPO="21StarkCom/homebrew-public"
# Entries that reach no target (spec D11). A marked copy of one is deleted.
# alfred stays here by the operator's request of 2026-10-29. muninn ships its
# bash source tree (STARK-17276). The operator let floorplan go on 2026-11-07,
# its readable JS tree included (STARK-17312).
EXCLUDED="alfred muninn"
# The only entries --target public copies (docs/specs/public-tap.md): an allow
# list, so a new entry stays out of the public tap until a PR names it here.
# Anyone can download their assets, so each holds no readable JS: the Go builds,
# and mimir, whose binary embeds a minified web UI. goldfinger is the one by-name
# exception: the operator let its readable Safari extension script go on
# 2026-11-21 (STARK-19531). EXCLUDED wins over it.
PUBLIC_ENTRIES="bragi frigg frigg-linux goldfinger heimdall lumiere mimir plume sonar sonar-linux stark-statusline tyr urd urd-linux"
# The package scopes of the operator's own code. A package under node_modules/
# in one of them is held to the source check (spec D12). Add a fleet repo's new
# scope here.
FIRST_PARTY_SCOPES="@21starkcom @atlas @floorplan @idun @sleipnir"
# A .ts file an entry names under libexec passes only as minified output: a mean
# line of this many bytes or more. Source runs at about 40.
MINIFIED_LINE_BYTES=200
MARKER='# Mirrored from 21StarkCom/homebrew-tap by scripts/mirror.sh. Do not edit: the next run overwrites it.'
FROZEN='# frozen_string_literal: true'
BEGIN_MARK='<!-- BEGIN 21stark-mirror -->'
END_MARK='<!-- END 21stark-mirror -->'
# Homebrew's rename maps at the tap root (spec D13): the one kind of file the copy
# merges into instead of owning, so they hold no marker line.
RENAME_FILES="formula_renames.json cask_renames.json"
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

dry_run=false branch=main check_entry="" check_file="" target=getevinced
declare -a only=() names=() changed_formulae=() changed_casks=()
declare -A kind=() rel=() src_repo=() src_id=() ver=() sha=() new_id=() new_name=() failed=() wanted=() excluded=()
tmp="" clone="" src_root="" src_rev="" created_branch=false auth_header=""
changed="" pushed=false rejected=false attempt=0

usage() {
  cat <<'EOF'
Usage: scripts/mirror.sh [--target getevinced|public] [--dry-run] [--branch <name>] [--only <entry>]...
       scripts/mirror.sh --check <entry> <archive>

Make a branch of the target tap match the entries of this checkout: each
entry's release asset is copied into a release of the target, and each entry
is written there with its asset URL pointed at that copy. alfred and muninn
are never copied.

  --target getevinced
                    the default: GetEvinced/homebrew-tap (GetEvinced/tap),
                    for the members of GetEvinced (docs/specs/getevinced-mirror.md)
  --target public   21StarkCom/homebrew-public (21StarkCom/public), for anyone
                    with no GitHub login (docs/specs/public-tap.md). It copies
                    only the entries of PUBLIC_ENTRIES, and deletes a marked
                    copy of any other entry. Each copy downloads from the
                    public release with no token: the copy drops the asset
                    URL's headers: or using: argument, the token lookup and
                    its check, the cask download adapter and the caveat that
                    asks for GitHub access, points homepage at the public
                    tap, and fails when a trace of the token code is left.
  --branch <name>   the target branch to push (default main); made from
                    main when it does not exist
  --only <entry>    copy only this entry (repeatable); delete no file and
                    change no rename file
  --dry-run         print the plan; upload, delete, commit and push nothing
  --check <entry> <archive>
                    run the source check of <entry> on a local .zip,
                    .tar.gz or .pkg, print each file it refuses, and exit;
                    needs no token and no network
  -h, --help        this text

The source check runs on each asset before its upload, and an asset that fails
it is not copied. It refuses, outside node_modules/: a .ts, .tsx, .mts or .cts
file that is not a declaration file (.d.ts), unless the entry names its path
under libexec and it holds minified output; a .map file; and a .json file that
holds "sourcesContent". In a package of a first-party scope under node_modules/
(FIRST_PARTY_SCOPES: @21starkcom, @atlas, @floorplan, @idun, @sleipnir), it
refuses those files with no exception, and any file that holds "sourcesContent".
Extensions match in any case. Anywhere outside node_modules/ or in such a
package, it refuses a JS, TS or CSS file with an inline source map
(sourceMappingURL=data:). It cannot judge readable JS: an unminified bundle,
the JS inside a binary, or an Electron app.asar, which it reads as one file.
A .pkg is a xar archive: bsdtar
unpacks it, and each member that is itself an archive (each Payload and Scripts),
and the check reads the tree. A .pkg fails when a member named *Payload does not
unpack (Apple's pbzx, say), or when it holds no Payload.

It reads Formula/*.rb, Casks/*.rb and Casks/*/*.rb (Casks/i/idavoll.rb), and a
copy keeps its path. It also reads formula_renames.json and cask_renames.json at
the root, when they exist, and merges each pair whose new name is a copied entry
of that kind into the same file of the target: a pair sets its old name there, a
pair it does not copy removes its old name there, and a target pair of another
old name stays. It writes no rename file that would be empty.
Run it from a checkout whose Formula/, Casks/ and rename files have no
uncommitted change.
To push main, HEAD must be origin/main (git fetch first).

Environment:
  MIRROR_SOURCE_TOKEN  reads the 21StarkCom release assets (not needed for --dry-run)
  MIRROR_TARGET_TOKEN  reads and writes the target repo: releases and the branch
                       (for --dry-run, a token that can read it is enough)
  MIRROR_GIT_NAME, MIRROR_GIT_EMAIL
                       the commit's author and committer (default: git's own)
  GITHUB_OUTPUT        when set, gets formulae=, casks= (the changed entries) and pushed=

For each entry, in this order: find the release <entry>-v<version> and its asset
whose digest is the pinned sha256; else download the source asset, check its
sha256 and its files, make the release as a draft, upload, and publish it. Then
write the entry with the marker line, the copy's asset URL, and 21starkcom/tap
renamed to the target's tap (getevinced/tap, or 21starkcom/public); for
getevinced, "21StarkCom private repos" is renamed too. A reused copy is not
checked again. Then delete marked files whose entry left this tap, moved,
or is excluded; merge the rename files; rewrite the README block; commit once and
push.
A push that loses a race clones again and writes again, up to three times. Files
without the marker line (aac, evinced) are never changed. No release and no
uploaded asset is ever deleted; an upload a dead run left (an hour old) is. The
rename files hold no marker line: the merge changes only the pairs above.

Exit: 0 every entry copied; 1 an entry failed (the others still pushed) or the
run failed; 2 usage. --check exits 0 when the archive passes, 1 when it does
not. Needs bash 4.4+, git, gh, jq, perl, tar, unzip and sha256sum or shasum
(--check: perl, tar and unzip only), and bsdtar (libarchive) for a .pkg.
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
# git toward the target: the token rides an http.extraheader in the environment,
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
  local others=0
  while (($# > 0))
  do
    case "$1" in
      -h | --help | help)
        usage
        exit 0
        ;;
      --dry-run)
        dry_run=true
        others=1
        ;;
      --branch)
        [[ $# -ge 2 && -n $2 ]] || usage_error "--branch needs a name"
        branch="$2"
        others=1
        shift
        ;;
      --only)
        [[ $# -ge 2 && $2 =~ ${ENTRY_RE} ]] || usage_error "--only needs an entry name"
        only+=("$2")
        others=1
        shift
        ;;
      --target)
        [[ $# -ge 2 && ($2 == getevinced || $2 == public) ]] || usage_error "--target needs getevinced or public"
        target="$2"
        others=1
        shift
        ;;
      --check)
        [[ $# -ge 3 && $2 =~ ${ENTRY_RE} && -n $3 ]] || usage_error "--check needs an entry name and an archive"
        check_entry="$2" check_file="$3"
        shift 2
        ;;
      *) usage_error "unknown argument: $1" ;;
    esac
    shift
  done
  [[ ${branch} =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || usage_error "bad branch name: ${branch}"
  [[ -z ${check_entry} || ${others} == 0 ]] || usage_error "--check takes no other option"
}

set_target() {
  case "${target}" in
    public)
      TARGET_REPO="${PUBLIC_REPO}" TARGET_TAP="21StarkCom/public" TARGET_SPEC="docs/specs/public-tap.md"
      ;;
    *)
      TARGET_REPO="GetEvinced/homebrew-tap" TARGET_TAP="GetEvinced/tap" TARGET_SPEC="docs/specs/getevinced-mirror.md"
      ;;
  esac
  TARGET_URL="https://github.com/${TARGET_REPO}.git"
}

# The copy is of what this checkout holds, so it must hold what main holds.
check_source() {
  local dirty head main
  ${dry_run} && return 0
  # shellcheck disable=SC2086 # RENAME_FILES is a list of plain names
  dirty="$(git -C "${src_root}" status --porcelain -- Formula Casks ${RENAME_FILES})" ||
    usage_error "${src_root} is not a git checkout"
  [[ -z ${dirty} ]] || usage_error "Formula/, Casks/ or a rename file has uncommitted changes:${NL}${dirty}"
  [[ ${branch} == main ]] || return 0
  head="$(git -C "${src_root}" rev-parse HEAD)"
  main="$(git -C "${src_root}" rev-parse -q --verify refs/remotes/origin/main)" ||
    usage_error "no origin/main in ${src_root}: git fetch origin main first"
  [[ ${head} == "${main}" ]] ||
    usage_error "HEAD ${head:0:7} is not origin/main ${main:0:7}: copy main only from a checkout of it (git fetch first)"
}

# Reads every Formula/ and Casks/ entry of this checkout into the arrays. Homebrew
# reads Casks/**/*.rb; idavoll's cask is in Casks/i/, which idavoll's own installer
# does not read, so the copy keeps that path too.
read_entries() {
  local f name line first n_url n_ver n_sha e q
  local -A listed=() seen=()
  for e in ${EXCLUDED}; do excluded[${e}]=1; done
  if [[ ${target} == public ]]
  then
    # An allow list: every other entry of this tap is excluded from the public tap.
    # A listed name that is both a formula and a cask stays listed, so the loop
    # below fails it as it does for GetEvinced.
    for e in ${PUBLIC_ENTRIES}; do listed[${e}]=1; done
    for f in "${src_root}"/Formula/*.rb "${src_root}"/Casks/*.rb "${src_root}"/Casks/*/*.rb
    do
      [[ -f ${f} ]] || continue
      name="${f##*/}"
      name="${name%.rb}"
      seen[${name}]=1
      [[ -n ${listed[${name}]:-} ]] || excluded[${name}]=1
    done
    for e in "${!listed[@]}"
    do
      [[ -n ${seen[${e}]:-} ]] || warn "PUBLIC_ENTRIES names ${e}, which is no entry of this tap"
    done
  fi
  for f in "${src_root}"/Formula/*.rb "${src_root}"/Casks/*.rb "${src_root}"/Casks/*/*.rb
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
      # Homebrew keeps formula and cask names apart, and one cask name to one
      # file; the copy keys by name.
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
    # The copy renames 21StarkCom/tap/<x> to the target's tap, where no excluded x
    # exists: such an entry stays out until it is excluded too. A . or + of a name
    # (ENTRY_RE) matches only itself.
    for e in "${!excluded[@]}"
    do
      q="${e//./[.]}"
      q="${q//+/[+]}"
      if grep -qiE "21starkcom/tap/${q}([^A-Za-z0-9_-]|\$)" "${f}"
      then
        fail_entry "${name}" "it names 21StarkCom/tap/${e}, which the mirror excludes; exclude ${name} too, or drop the reference"
        break
      fi
    done
  done
  ((${#names[@]} > 0)) || die "no entry to copy in ${src_root}"
  # Of each pair in a source rename file, keep the one whose new name is an entry
  # of that kind here; failed entries count, excluded ones are no entry here.
  local file want old new
  for file in ${RENAME_FILES}
  do
    want=formula
    [[ ${file} != cask_* ]] || want=cask
    : >"${tmp}/${file}.kept"
    : >"${tmp}/${file}.dropped"
    [[ -f "${src_root}/${file}" ]] || continue
    if ! renames_ok "${src_root}/${file}"
    then
      : >"${tmp}/${file}.bad"
      fail_entry "${file}" "it is not a JSON object of entry names to entry names; no pair of it is copied"
      continue
    fi
    jq -r 'to_entries[] | [.key, .value] | @tsv' "${src_root}/${file}" >"${tmp}/${file}.pairs"
    while IFS=$'\t' read -r old new
    do
      if [[ ${kind[${new}]:-} == "${want}" ]]
      then
        jq -nc --arg o "${old}" --arg n "${new}" '{($o): $n}' >>"${tmp}/${file}.kept"
      else
        say "${file}: ${old} -> ${new} is not copied: ${new} is no ${want} of the mirror"
        printf '%s\n' "${old}" >>"${tmp}/${file}.dropped"
      fi
    done <"${tmp}/${file}.pairs"
  done
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

# Prints each TypeScript path that entry file $1 names under libexec, one per
# line: the minified bundles its wrappers and tests run (sleipnir).
named_ts() {
  perl -ne 'print "$1\n" while m{(?:#\{(?:opt_)?libexec\}/|(?:opt_)?libexec/")([^"\s#{}]+?\.(?:ts|tsx|mts|cts))(?![A-Za-z0-9_])}g' "$1"
}

# Unpacks the flat .pkg $1, a xar archive, into the empty folder $2, and lists the
# files and links of the tree in $3, one per line. Each member that bsdtar reads as
# an archive (a Payload or a Scripts, each a cpio archive) is unpacked in its place.
# bsdtar finds them by their bytes, not by their names: libarchive joins a name
# that the table of contents gives twice, and idavoll's .pkg gives each name twice
# (PayloadPayload). A member whose name ends in Payload must unpack: a Payload
# left as one file would pass unread. Says why on stderr and returns 1 when it cannot.
unpack_pkg() { # <pkg> <dir> <list>
  local m n=0
  # Only the bytes count. Ubuntu's bsdtar cannot write the macOS extended
  # attributes of idavoll's members (com.apple.provenance) and fails on them.
  local -a plain=(--no-xattrs --no-acls --no-fflags)
  local -a members=()
  if ! command -v bsdtar >/dev/null
  then
    echo "bsdtar (libarchive) is required to read a .pkg" >&2
    return 1
  fi
  bsdtar -xf "$1" -C "$2" "${plain[@]}" || return 1
  # Every member first, so the tree unpacked in a member's place is not read again.
  find "$2" -type f -print0 >"${tmp}/members" || return 1
  mapfile -d '' members <"${tmp}/members"
  for m in "${members[@]}"
  do
    : >"${tmp}/member.err"
    # libarchive reads an empty file as an empty archive; it is no Payload.
    if [[ -s ${m} ]]
    then
      mv "${m}" "${tmp}/member" || return 1
      mkdir "${m}" || return 1
      # One pass: a member that does not unpack goes back in its place, as a file.
      if bsdtar -xf "${tmp}/member" -C "${m}" "${plain[@]}" 2>"${tmp}/member.err"
      then
        rm -f "${tmp}/member"
        [[ ${m##*/} != *Payload ]] || n=$((n + 1))
        continue
      fi
      rm -rf "${m}"
      mv "${tmp}/member" "${m}" || return 1
    fi
    if [[ ${m##*/} == *Payload ]]
    then
      echo "its ${m#"$2"/} is no archive that bsdtar reads, so it cannot be checked. $(<"${tmp}/member.err")" >&2
      return 1
    fi
  done
  if ((n == 0))
  then
    echo "it holds no Payload to check" >&2
    return 1
  fi
  (cd "$2" && find . ! -type d) >"$3"
}

# The source check (spec D12): unpacks archive $2 of entry $1, whose file is $3,
# and fails the entry when a file in it is source (usage names the rules).
# Returns 1 when it fails the entry.
scan_asset() { # <entry> <archive> <entry file>
  local name="$1" archive="$2" dir="${tmp}/scan" named n first rc=0
  rm -rf "${dir}"
  mkdir -p "${dir}"
  case "${archive}" in
    *.zip)
      { unzip -Z1 "${archive}" >"${tmp}/scan.list" && unzip -qq -o "${archive}" -d "${dir}"; } 2>"${tmp}/scan.err" || rc=$?
      ;;
    *.tar.gz | *.tgz)
      { tar -tzf "${archive}" >"${tmp}/scan.list" && tar -xzf "${archive}" -C "${dir}"; } 2>"${tmp}/scan.err" || rc=$?
      ;;
    *.pkg)
      unpack_pkg "${archive}" "${dir}" "${tmp}/scan.list" 2>"${tmp}/scan.err" || rc=$?
      ;;
    *)
      fail_entry "${name}" "the source check reads only a .zip, a .tar.gz or a .pkg, not ${archive##*/}"
      return 1
      ;;
  esac
  if ((rc != 0))
  then
    fail_entry "${name}" "the source check cannot unpack ${archive##*/}: $(<"${tmp}/scan.err")"
    rm -rf "${dir}"
    return 1
  fi
  named="$(named_ts "$3")" || named=""
  ROOT="${dir}" NAMED="${named}" SCOPES="${FIRST_PARTY_SCOPES}" MINLINE="${MINIFIED_LINE_BYTES}" perl -e '
    use strict;
    use warnings;
    my %named = map { $_ => 1 } split /\n/, $ENV{NAMED};
    my %scope = map { $_ => 1 } split " ", $ENV{SCOPES};
    # Extensions match in any case: a .TS or .Map on a case-blind disk is the same file.
    my $ts = qr/\.(?:ts|tsx|mts|cts)\z/i;
    my $decl = qr/\.d\.(?:ts|mts|cts)\z/i;
    my $text = qr/\.(?:js|mjs|cjs|jsx|ts|tsx|mts|cts|css)\z/i;
    my $json = qr/\.json\z/i;
    # The bytes of a regular file; undef for a link or a directory.
    sub body {
      my $f = "$ENV{ROOT}/$_[0]";
      return undef if -l $f || !-f $f;
      open my $h, "<:raw", $f or die "cannot read $_[0]: $!\n";
      local $/;
      return scalar <$h>;
    }
    # Why the file at path $_[0] is source, or "" when it is not; $_[1] is true
    # in a first-party package. (Postfix conditions only: brew style misreads a
    # line in a string that starts with an if.)
    sub why {
      my ($p, $ours) = @_;
      my $in = $ours ? " in a first-party package" : "";
      my $source = $p =~ $ts && $p !~ $decl;
      my $bundle = $source && !$ours && $named{$p};
      return "TypeScript source$in" if $source && !$bundle;
      return "a source map$in" if $p =~ /\.map\z/i;
      return "" unless $ours || $p =~ $text || $p =~ $json;
      my $b = body($p);
      return $bundle ? "a named TypeScript path that is not a plain file" : "" unless defined $b;
      my $mean = int(length($b) / (($b =~ tr/\n//) + ($b =~ /[^\n]\z/ ? 1 : 0) || 1));
      return "TypeScript source, not minified (a mean line of $mean bytes)" if $bundle && $mean < $ENV{MINLINE};
      # A .json outside node_modules/ that holds sourcesContent is a source map by another name.
      return "holds sourcesContent$in" if ($ours || $p =~ $json) && index($b, "sourcesContent") >= 0;
      return "an inline source map$in" if $p =~ $text && $b =~ /sourceMappingURL=data:/;
      return "";
    }
    while (my $p = <STDIN>) {
      chomp $p;
      $p =~ s{\A(?:\./)+}{};
      next if $p eq "" || $p =~ m{/\z};
      # Under node_modules/, only a package of a first-party scope is read: the
      # package after the last node_modules/ in the path.
      my ($rest) = $p =~ m{.*(?:\A|/)node_modules/(.*)\z};
      my $ours = defined $rest && $rest =~ m{\A(@[^/]+)/[^/]+/} && $scope{$1} ? 1 : 0;
      next if defined $rest && !$ours;
      my $why = why($p, $ours);
      print "$p: $why\n" if $why ne "";
    }
  ' <"${tmp}/scan.list" >"${tmp}/scan.hits" 2>"${tmp}/scan.err" || rc=$?
  rm -rf "${dir}"
  if ((rc != 0))
  then
    fail_entry "${name}" "the source check of ${archive##*/} did not run: $(<"${tmp}/scan.err")"
    return 1
  fi
  n="$(wc -l <"${tmp}/scan.hits")"
  n=$((n))
  ((n > 0)) || return 0
  head -n 20 "${tmp}/scan.hits" | sed "s|^|mirror.sh: ${name}: |" >&2
  ((n <= 20)) || warn "${name}: and $((n - 20)) more"
  first="$(head -n 1 "${tmp}/scan.hits")"
  fail_entry "${name}" "${archive##*/} holds source in ${n} file(s), so it is not copied; the first is ${first}"
  return 1
}

# --check: the source check of one entry on a local archive, with no token.
check_archive() {
  local f tool
  local -a files=("${src_root}/Formula/${check_entry}.rb" "${src_root}/Casks/${check_entry}.rb"
    "${src_root}"/Casks/*/"${check_entry}.rb") found=()
  for tool in perl tar unzip
  do
    command -v "${tool}" >/dev/null || die "${tool} is required"
  done
  [[ -f ${check_file} ]] || usage_error "--check: no such archive: ${check_file}"
  for f in "${files[@]}"
  do
    [[ ! -f ${f} ]] || found+=("${f#"${src_root}"/}")
  done
  ((${#found[@]} > 0)) || usage_error "--check ${check_entry}: no such entry in this tap"
  # As read_entries does: the mirror copies neither of two files with one name.
  ((${#found[@]} == 1)) || die "${check_entry}: is both ${found[0]} and ${found[1]}; the mirror copies neither"
  f="${src_root}/${found[0]}"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/mirror.XXXXXX")"
  trap cleanup EXIT
  scan_asset "${check_entry}" "${check_file}" "${f}" || exit 1
  say "${check_entry}: ${check_file##*/} passes the source check"
}

# Clones the target branch into $clone, from main when the branch is new.
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

# True when file $1 holds one JSON object whose keys and values are entry names.
# jq's $ also matches before a last newline, so a name must not end in one.
renames_ok() {
  jq -se --arg re "${ENTRY_RE}" '
    def name: type == "string" and test($re) and (endswith("\n") | not);
    length == 1 and (.[0] | type == "object" and all(to_entries[]; (.key | name) and (.value | name)))' \
    "$1" >/dev/null 2>&1
}

# Fails each entry whose file in the target exists without the marker line.
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

# Sets new_id[$1] and new_name[$1] to an asset of the target with the entry's
# bytes: an uploaded copy found by its digest, or one this run uploads. Fails the
# entry on any error.
ensure_asset() {
  local name="$1" tag release="" rjson rid draft found sname file got uname taken asset state digest busy body
  tag="${name}-v${ver[${name}]}"
  find_release "${tag}" || {
    fail_entry "${name}" "${TARGET_REPO} has more than one release tagged ${tag}; delete the extra one"
    return 0
  }
  if [[ -n ${release} ]]
  then
    rid="$(jq -r .id <<<"${release}")"
    draft="$(jq -r .draft <<<"${release}")"
    # Its id and name, one tab apart: an asset name holds no tab.
    found="$(jq -r --arg d "sha256:${sha[${name}]}" \
      '[.assets[] | select(.state == "uploaded" and .digest == $d)][0] // empty | "\(.id)\t\(.name)"' <<<"${release}")"
    if [[ -n ${found} ]]
    then
      # A draft here holds the asset of a run that stopped before publishing.
      if [[ ${draft} == true ]] && ! ${dry_run}
      then
        publish_release "${name}" "${rid}" "${tag}" || return 0
      fi
      new_id[${name}]="${found%%$'\t'*}"
      new_name[${name}]="${found#*$'\t'}"
      say "${name} ${ver[${name}]}: reuse asset ${new_id[${name}]} of release ${tag}"
      return 0
    fi
  fi
  if ${dry_run}
  then
    # A stand-in id and name, so the plan shows the file this copy would change.
    new_id[${name}]=0
    new_name[${name}]="dry-run-asset"
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
  if ! scan_asset "${name}" "${file}" "${src_root}/${rel[${name}]}"
  then
    rm -f "${file}"
    return 0
  fi

  if [[ -z ${release} ]]
  then
    if [[ ${target} == public ]]
    then
      body="The release asset \`${sname}\` of \`${name}\` ${ver[${name}]} for the Homebrew tap ${TARGET_TAP}, SHA-256 \`${sha[${name}]}\`, copied by scripts/mirror.sh of 21StarkCom/homebrew-tap."
    else
      body="A copy of ${src_repo[${name}]} release asset ${src_id[${name}]} (\`${sname}\`), SHA-256 \`${sha[${name}]}\`, made by scripts/mirror.sh of 21StarkCom/homebrew-tap for its GetEvinced/tap entry \`${name}\`."
    fi
    rid="$(dst_gh api -X POST "repos/${TARGET_REPO}/releases" -f tag_name="${tag}" -f target_commitish=main \
      -f name="${name} ${ver[${name}]}" -F draft=true -f make_latest=false -f body="${body}" \
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
  new_name[${name}]="${uname}"
  say "${name} ${ver[${name}]}: uploaded asset ${new_id[${name}]}"
}

# Writes the copy of entry $1 into the clone (the spec's "The copy of an entry";
# for --target public, docs/specs/public-tap.md adds its rules). With --check, it
# only makes the copy, with a stand-in asset, and fails the entry when it cannot.
# No line of the perl starts with `if`: brew style's layout pass misreads one in a
# string, and re-indents the shell code after it.
write_copy() {
  local name="$1" check="${2:-}" out home dl
  home="https://github.com/${TARGET_REPO}"
  dl="${home}/releases/download/${name}-v${ver[${name}]}/${new_name[${name}]:-}"
  out="$(TARGET="${target}" TARGET_REPO="${TARGET_REPO}" NEWID="${new_id[${name}]:-0}" MARKER="${MARKER}" FROZEN="${FROZEN}" \
    PUBLIC_URL="${dl}" PUBLIC_HOME="${home}" perl -0777 -ne '
    my $first = "$ENV{FROZEN}\n";
    substr($_, 0, length $first) eq $first or die "its first line is not $ENV{FROZEN}\n";
    my $rest = substr($_, length $first);
    $rest =~ s/\A\n//;
    my $url = qr{^([ \t]*url[ \t]+"https://api\.github\.com/repos/)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/releases/assets/)[0-9]+"}m;
    my $n = 0;
    $n++ while $rest =~ /$url/g;
    $n == 1 or die "it has $n asset url stanzas\n";
    my $public = $ENV{TARGET} eq "public";
    $public or do {
      $rest =~ s/$url/$1$ENV{TARGET_REPO}$2$ENV{NEWID}"/;
      $rest =~ s{(21starkcom)(/tap)\b}{($1 eq lc($1) ? "getevinced" : "GetEvinced") . $2}gie;
      $rest =~ s{read access to 21StarkCom private repos}{read access to GetEvinced private repos}g;
    };
    # The public copy downloads a public release with no token, so the token code goes.
    $public and do {
      # The asset URL, with the one argument line that may follow it: a headers:
      # array on that line, or a using: class. Any other argument fails the entry.
      $rest =~ s{^([ \t]*url[ \t]+)"https://api\.github\.com/repos/[^"\n]+"(?:,[ \t]*\n[ \t]*(?:headers:[ \t]*\[[^\]\n]*\]|using:[ \t]*[A-Za-z0-9_:]+))?[ \t]*$}{$1"$ENV{PUBLIC_URL}"}m;
      $rest =~ m{^[ \t]*url[ \t]+"[^"\n]*",}m and die "its url stanza has an argument the public copy cannot drop\n";
      # A formula: the token lookup, its check, and the comment block right above
      # the lookup, which explains the pin, the bumper and the token.
      $rest =~ s{(?:^[ \t]*#[^\n]*\n)*^([ \t]*)worker = %w\[[^\]\n]*\]\.any\? do \|w\|[ \t]*\n.*?^\1end[ \t]*\n}{}ms;
      $rest =~ s{(?:^[ \t]*#[^\n]*\n)*^[ \t]*worker = %w\[[^\]\n]*\]\.any\? \{[^\n]*\}[ \t]*\n}{}m;
      $rest =~ s{^[ \t]*token = worker \? "" : GitHub::API\.credentials\.to_s\.strip[ \t]*\n}{}m;
      $rest =~ s{^([ \t]*)if token\.empty\? && !worker[ \t]*\n.*?^\1end[ \t]*\n}{}ms;
      $rest =~ s{^[ \t]*# (?:API asset URL \(private repo\)|Homebrew.s own lookup:|Its sandboxed build, test and postinstall workers|config\. They never download|So does its fix_linkage worker)[^\n]*\n}{}mg;
      # A cask: its download adapter, and the comment above it.
      $rest =~ s{^require "download_strategy"[ \t]*\n(?:[ \t]*\n)?}{}m;
      $rest =~ s{^# Cask URL specs are serialized[^\n]*\n# credential in the downloader only[^\n]*\n}{}m;
      $rest =~ s{^class [A-Za-z0-9_]+ < CurlDownloadStrategy[ \t]*\n.*?^end[ \t]*\n(?:[ \t]*\n)?}{}ms;
      # The caveat that asks for GitHub access, in a heredoc or on one line.
      $rest =~ s{^[ \t]*Installing needs GitHub read access to 21StarkCom private repos:[^\n]*\n[ \t]*in \(`brew install gh && gh auth login`\), or export HOMEBREW_GITHUB_API_TOKEN=<token>[ \t]*\n(?:[ \t]*\n)?}{}m;
      $rest =~ s{^[ \t]*caveats "Installing needs GitHub read access to 21StarkCom private repos[^"\n]*"[ \t]*\n}{}m;
      $rest =~ s{^[ \t]*caveats <<~EOS[ \t]*\n[ \t]*EOS[ \t]*\n}{}m;
      $rest =~ s{\n[ \t]*\n(end[ \t]*\n?)\z}{\n$1};
      # The source repo is private: its page is no homepage for the public.
      $rest =~ s{^([ \t]*homepage[ \t]+)"https://github\.com/21StarkCom/[A-Za-z0-9_.-]+"}{$1"$ENV{PUBLIC_HOME}"}m;
      $rest =~ s{(21starkcom)/tap\b}{$1/public}gi;
      foreach my $left ("GitHub::API", "Authorization:", "CurlDownloadStrategy", "api.github.com/repos/",
        "HOMEBREW_GITHUB_API_TOKEN", "private repos") {
        index($rest, $left) < 0 or die "the public copy still holds $left: its token code has a shape the copy does not know\n";
      }
    };
    $rest =~ m{21starkcom/tap\b}i and die "the copy still names 21starkcom/tap\n";
    print $first, "\n", $ENV{MARKER}, "\n\n", $rest;
  ' "${src_root}/${rel[${name}]}" 2>"${tmp}/perl.err")" || {
    fail_entry "${name}" "cannot copy ${rel[${name}]}: $(<"${tmp}/perl.err")"
    return 0
  }
  [[ -z ${check} ]] || return 0
  mkdir -p "${clone}/${rel[${name}]%/*}"
  printf '%s\n' "${out}" >"${clone}/${rel[${name}]}"
}

# Deletes each marked file of the target whose entry left this tap, moved (between
# Formula/ and Casks/, or into or out of a Casks/ subfolder), or is excluded.
remove_departed() {
  local f name path why
  for f in "${clone}"/Formula/*.rb "${clone}"/Casks/*.rb "${clone}"/Casks/*/*.rb
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

# Merges the pairs read_entries kept into each rename file of the clone (spec
# D13): a kept pair sets its old name, a dropped one removes its old name, and a
# pair whose old name the source file lacks stays. A kept pair whose new entry
# failed and has no copy in the clone waits, so no old name moves to nothing.
# Writes no file that would hold no pair, and leaves a file whose pairs do not
# change as it is.
write_renames() {
  local file dst base merged pairs new
  local -a held
  for file in ${RENAME_FILES}
  do
    [[ ! -e "${tmp}/${file}.bad" ]] || continue
    # A retry after a lost push race reads a new clone: forget an older clone's fault.
    unset 'failed[${file}]'
    dst="${clone}/${file}"
    base='{}'
    if [[ -e ${dst} ]]
    then
      if ! renames_ok "${dst}"
      then
        fail_entry "${file}" "${TARGET_REPO} has a ${file} that is not a JSON object of entry names; it is left as it is"
        continue
      fi
      base="$(jq -c . "${dst}")"
    fi
    held=()
    jq -r '.[]' "${tmp}/${file}.kept" >"${tmp}/${file}.new"
    while IFS= read -r new
    do
      [[ -n ${new} && -n ${failed[${new}]:-} ]] || continue
      ! marked "${clone}/${rel[${new}]}" || continue
      say "${file}: the pair to ${new} waits: ${new} failed and has no copy in ${TARGET_REPO}"
      held+=("${new}")
    done <"${tmp}/${file}.new"
    merged="$(jq -nc --argjson base "${base}" --slurpfile kept "${tmp}/${file}.kept" \
      --rawfile dropped "${tmp}/${file}.dropped" \
      '($base | delpaths([$dropped | split("\n")[] | select(. != "") | [.]]))
        + ($kept | add // {} | with_entries(select(.value | IN($ARGS.positional[]) | not)))' \
      --args "${held[@]}")" ||
      die "cannot merge ${file}"
    if [[ ! -e ${dst} ]]
    then
      [[ ${merged} != "{}" ]] || continue
    elif jq -e --argjson m "${merged}" '. == $m' "${dst}" >/dev/null
    then
      continue
    fi
    jq . <<<"${merged}" >"${dst}"
    pairs="$(jq -r 'to_entries | map("\(.key) -> \(.value)") | join(", ")' <<<"${merged}")"
    say "${file}: writing ${pairs}"
  done
}

# Rewrites the README block from the marked files in the clone.
write_readme() {
  local block f name k v home line sep=""
  if [[ ${target} == public ]]
  then
    block="${BEGIN_MARK}
## Install

The mirror job of \`21StarkCom/homebrew-tap\` (its \`scripts/mirror.sh\`) writes this
section and every file that holds its marker line. A change made here is lost at
its next run. Each of these entries downloads its asset from a public release of
this repo, so installing needs no GitHub login and no token.

\`\`\`sh
brew tap ${TARGET_TAP}
brew trust --tap ${TARGET_TAP}
brew install ${TARGET_TAP}/<entry>
brew install --cask ${TARGET_TAP}/<cask>
\`\`\`

A Mac that also taps \`21StarkCom/tap\` must use full names in every \`brew\`
command, \`brew services\` included, for example \`${TARGET_TAP}/tyr\`.

| Entry | Kind | Version |
|---|---|---|"
  else
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
  fi
  for f in "${clone}"/Formula/*.rb "${clone}"/Casks/*.rb "${clone}"/Casks/*/*.rb
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
    if [[ ${target} == public ]]
    then
      block+="${NL}| \`${name}\` | ${k} | ${v} |"
    else
      block+="${NL}| \`${name}\` | ${k} | ${v} | [${home#https://github.com/}](${home}) |"
    fi
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
    # A new public README starts with the tap's name. GetEvinced's README is the
    # Evinced team's: the job writes only its block there (spec D6).
    if [[ ${target} == public && ! -s "${clone}/README.md" ]]
    then
      printf '# %s\n' "${TARGET_TAP}" >"${clone}/README.md"
    fi
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
  if ((${#only[@]} == 0))
  then
    remove_departed
    write_renames
  fi
  write_readme
  cgit add -A
  cgit diff --cached --name-only >"${tmp}/changed"
  changed_formulae=() changed_casks=() changed=""
  while IFS= read -r path
  do
    if [[ " ${RENAME_FILES} " == *" ${path} "* ]]
    then
      changed+="${NL}- ${path}"
      continue
    fi
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
      -m "Copied by scripts/mirror.sh (${TARGET_SPEC}).${changed:+${NL}${changed}}"
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
  set_target
  src_root="$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
  if [[ -n ${check_entry} ]]
  then
    check_archive
    return 0
  fi
  local tool
  for tool in git gh jq perl tar unzip
  do
    command -v "${tool}" >/dev/null || die "${tool} is required"
  done
  command -v sha256sum >/dev/null || command -v shasum >/dev/null || die "sha256sum or shasum is required"
  [[ -n ${MIRROR_TARGET_TOKEN:-} ]] || usage_error "MIRROR_TARGET_TOKEN is not set"
  ${dry_run} || [[ -n ${MIRROR_SOURCE_TOKEN:-} ]] || usage_error "MIRROR_SOURCE_TOKEN is not set"
  auth_header="AUTHORIZATION: basic $(printf 'x-access-token:%s' "${MIRROR_TARGET_TOKEN}" | base64 | tr -d '\n')"

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
    # A public upload cannot be called back: an entry whose copy fails uploads nothing.
    [[ ${target} != public ]] || write_copy "${name}" --check
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
