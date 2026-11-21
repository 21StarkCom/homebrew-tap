#!/usr/bin/env bash
# scripts/test-bump.sh: tests for scripts/bump.sh (ADR-0008). bump.sh runs from
# a depth-1 clone of a local bare "tap" remote with real git; gh is a stub that
# answers from fixtures and from that remote. Never the real tap. Also the
# Decision 4 workflow-set test. .github/workflows/bump.yml runs it on ubuntu, and
# in the bash:3.2 image, where 3.2 is the only bash. BUMP_TEST_BASH is the bash
# that runs bump.sh (on a Mac, /bin/bash is 3.2).
#
# brew style (formulae.yml) lints this with every optional shellcheck check. Off:
# each check is an eval'd string, read at eval time (SC2016, SC2034); a case with
# no match has nothing to do (SC2249); fixture pipelines fail loudly downstream
# (SC2310, SC2312).
# shellcheck disable=SC2016,SC2034,SC2249,SC2310,SC2312
set -uo pipefail

here="$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}" && pwd -P)"
root="${here%/*}"
for tool in git perl jq ruby mktemp
do
  command -v "${tool}" >/dev/null || {
    echo "test-bump.sh: ${tool} is required" >&2
    exit 1
  }
done
# The .pkg test makes a xar archive with bsdtar. Alpine's libarchive cannot write one,
# so bump.yml's bash 3.2 job sets BUMP_TEST_SKIP_PKG=1.
[[ -n "${BUMP_TEST_SKIP_PKG:-}" ]] || command -v bsdtar >/dev/null || {
  echo "test-bump.sh: bsdtar is required (BUMP_TEST_SKIP_PKG=1 skips the .pkg test)" >&2
  exit 1
}
sut_bash="$(command -v "${BUMP_TEST_BASH:-bash}")" || {
  echo "test-bump.sh: no bash at ${BUMP_TEST_BASH:-bash}" >&2
  exit 1
}
echo "bump.sh runs under $("${sut_bash}" -c 'echo "bash $BASH_VERSION"')"

work="$(mktemp -d "${TMPDIR:-/tmp}/test-bump.XXXXXX")"
trap 'rm -rf "$work"' EXIT
# Real git, isolated from the machine's config.
export HOME="${work}/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="${work}/gitconfig" GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=bump-test GIT_AUTHOR_EMAIL=bump-test@example.invalid
export GIT_COMMITTER_NAME=bump-test GIT_COMMITTER_EMAIL=bump-test@example.invalid
mkdir -p "${HOME}"
printf '[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n' >"${GIT_CONFIG_GLOBAL}"

TAP=21StarkCom/homebrew-tap
ONES=1111111111111111111111111111111111111111111111111111111111111111
ZERO=0000000000000000000000000000000000000000000000000000000000000000
passed=0 failed=0 rigs=0 name="" code=0 out="" err=""
NL=$'\n'

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

# --- assertions ------------------------------------------------------------

begin() {
  name="$1"
  printf '\n# %s\n' "${name}"
}
pass() {
  passed=$((passed + 1))
  printf 'ok   %s\n' "$1"
}
flunk() {
  failed=$((failed + 1))
  printf 'FAIL %s: %s\n' "${name}" "$1"
  printf '     exit %s\n     stdout: %s\n' "${code}" "${out}"
  printf '%s\n' "${err}" | sed 's/^/     stderr: /' | tail -n 25
}
check() { # check <what> <command...>
  local what="$1"
  shift
  if "$@"; then pass "${what}"; else flunk "${what}"; fi
}
is_code() { [[ "${code}" = "$1" ]]; }
stdout_is() { [[ "${out}" = "$1" ]]; }
has() {
  case "$1" in *"$2"*) return 0 ;; esac
  return 1
}
stderr_has() { has "${err}" "$1"; }
stderr_lacks() { ! has "${err}" "$1"; }
# Calls the gh stub logged whose arguments start with $1.
gh_calls() { grep -c "^$1" "${R}/gh/log" 2>/dev/null || true; }
no_gh() { [[ "$(gh_calls "")" = 0 ]]; }

# --- the rig: a bare tap remote, a depth-1 clone, and the gh stub ------------

formula_text() { # <version> <asset id> <sha256>
  printf '%s\n' \
    'class Demo < Formula' \
    '  desc "Demo"' \
    '  homepage "https://github.com/21StarkCom/demo"' \
    '  # A comment naming releases/assets/999 is not the url line, and stays.' \
    "  url \"https://api.github.com/repos/21StarkCom/demo/releases/assets/$2\"," \
    '      headers: ["Accept: application/octet-stream"]' \
    "  version \"$1\"" \
    "  sha256 \"$3\"" \
    '' \
    '  def install' \
    '    bin.install "demo"' \
    '  end' \
    'end'
}

cask_text() { # <version> <asset id> <sha256>
  printf '%s\n' \
    'cask "democask" do' \
    "  version \"$1\"" \
    "  sha256 \"$3\"" \
    '' \
    "  url \"https://api.github.com/repos/21StarkCom/democask/releases/assets/$2\"," \
    '      using: DemocaskStrategy' \
    '  name "Democask"' \
    'end'
}

write_stub() {
  cat >"$1" <<'STUB'
#!/usr/bin/env bash
# gh, as far as bump.sh uses it: release reads and asset downloads from fixtures
# in $FAKE_GH, the compare API from the bare $FAKE_REMOTE, and PRs as directories.
set -u
S="$FAKE_GH"
TAP=21StarkCom/homebrew-tap
line="$*" nl=$'\n'
printf '%s\n' "${line//$nl/ }" >>"$S/log"
g() { git --git-dir="$FAKE_REMOTE" "$@"; }
nf() {
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
}
bad() {
  echo "gh stub: $*" >&2
  exit 91
}
cmd="$1" sub=""
shift
# No multi-line `if` in this heredoc: brew style's shfmt wrapper misreads one.
[ "$cmd" != pr ] || {
  sub="$1"
  shift
}
jqx="" accept="" path="" repo="" head="" state_f="" title="" body="" match="" num="" squash=false del=false
add_l="" rm_l="" method=GET fields="" input=""
# The sha256 of file $1.
h() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -c1-64; }
while [ $# -gt 0 ]
do
  case "$1" in
    -H) accept="$2"; shift ;;
    -X) method="$2"; shift ;;
    -f | -F) fields="$fields$2$nl"; shift ;;
    --input) input="$2"; shift ;;
    --jq) jqx="$2"; shift ;;
    -R) repo="$2"; shift ;;
    --head) head="$2"; shift ;;
    --base) [ "$2" = main ] || bad "base $2"; shift ;;
    --state) state_f="$2"; shift ;;
    --json) shift ;;
    --title) title="$2"; shift ;;
    --body) body="$2"; shift ;;
    --add-label) add_l="$add_l$2$nl"; shift ;;
    --remove-label) rm_l="$rm_l$2$nl"; shift ;;
    --match-head-commit) match="$2"; shift ;;
    --squash) squash=true ;;
    --delete-branch) del=true ;;
    -*) bad "unexpected flag $1" ;;
    *) if [ "$cmd" = api ]; then path="$1"; else num="$1"; fi ;;
  esac
  shift
done
emit() { if [ -n "$jqx" ]; then jq -r "$jqx"; else cat; fi; }
case "$cmd" in
  api)
    case "$path" in
      repos/*/releases/assets/*)
        [ "$accept" = "Accept: application/octet-stream" ] || bad "asset read without octet-stream"
        [ -f "$S/assets/${path##*/}" ] || nf
        cat "$S/assets/${path##*/}"
        ;;
      "repos/$TAP/releases")
        # A new release of the tap, a draft: $S/rel/<id>.{tag,fields,assets}.
        [ "$method" = POST ] || bad "releases without POST"
        [ ! -f "$S/release.fail" ] || { echo "gh: Validation Failed (HTTP 422)" >&2; exit 1; }
        id=$(($(cat "$S/next_release" 2>/dev/null || echo 900) + 1))
        echo "$id" >"$S/next_release"
        mkdir -p "$S/rel"
        printf '%s' "$fields" | sed -n 's/^tag_name=//p' >"$S/rel/$id.tag"
        printf '%s' "$fields" >"$S/rel/$id.fields"
        : >"$S/rel/$id.assets"
        jq -n --argjson id "$id" '{id: $id}' | emit
        ;;
      "https://uploads.github.com/repos/$TAP/releases/"*)
        [ "$method" = POST ] || bad "upload without POST"
        rid="${path#https://uploads.github.com/repos/$TAP/releases/}"
        rid="${rid%%/*}"
        [ -f "$S/rel/$rid.tag" ] || nf
        [ -f "$input" ] || bad "upload without --input"
        aid=$(($(cat "$S/next_asset" 2>/dev/null || echo 5000) + 1))
        echo "$aid" >"$S/next_asset"
        cp "$input" "$S/assets/$aid"
        printf '%s %s\n' "$aid" "${path##*name=}" >>"$S/rel/$rid.assets"
        dig="sha256:$(h "$S/assets/$aid")"
        [ ! -f "$S/upload.bad" ] || dig="sha256:0000000000000000000000000000000000000000000000000000000000000000"
        [ ! -f "$S/upload.nodigest" ] || dig=""
        jq -n --argjson id "$aid" --arg n "${path##*name=}" --arg d "$dig" '{id: $id, name: $n, state: "uploaded", digest: (if $d == "" then null else $d end)}' | emit
        ;;
      "repos/$TAP/releases/"[0-9]*)
        # Publishing a draft makes its tag readable, as on GitHub.
        [ "$method" = PATCH ] || bad "release $path without PATCH"
        rid="${path##*/}"
        [ -f "$S/rel/$rid.tag" ] || nf
        mkdir -p "$S/api/repos/$TAP/releases/tags"
        while read -r aid an; do jq -n --argjson id "$aid" --arg n "$an" --arg d "sha256:$(h "$S/assets/$aid")" '{id: $id, name: $n, state: "uploaded", digest: $d}'; done <"$S/rel/$rid.assets" |
          jq -s --argjson id "$rid" '{id: $id, assets: .}' >"$S/api/repos/$TAP/releases/tags/$(cat "$S/rel/$rid.tag").json"
        echo '{}'
        ;;
      "repos/$TAP/compare/main..."*)
        tip="${path##*...}"
        g cat-file -e "$tip^{commit}" 2>/dev/null || nf
        files="$(g diff --name-only "main...$tip")"
        jq -n --argjson ahead "$(g rev-list --count "main..$tip")" --arg tree "$(g rev-parse "$tip^{tree}")" \
          --arg files "$files" --arg patch "$(g diff "main...$tip" -- "${files%%"$nl"*}" | sed -n '/^@@/,$p')" '
          {ahead_by: $ahead, commits: [{commit: {tree: {sha: $tree}}}],
           files: ($files | split("\n") | map(select(. != "")) | to_entries
                   | map({filename: .value, patch: (if .key == 0 then $patch else "" end)}))}' | emit
        ;;
      "repos/$TAP/actions/runs?"*)
        [ ! -f "$S/runs.403" ] || {
          echo '{"message":"Resource not accessible by personal access token","status":"403"}'
          echo "gh: Resource not accessible by personal access token (HTTP 403)" >&2
          exit 1
        }
        [ ! -f "$S/runs.ratelimit" ] || {
          echo '{"message":"API rate limit exceeded for user ID 1.","status":"403"}'
          echo "gh: API rate limit exceeded for user ID 1. (HTTP 403)" >&2
          exit 1
        }
        sha="${path#*head_sha=}"
        sha="${sha%%&*}"
        f="$S/runs.json"
        [ ! -f "$S/runs.$sha.json" ] || f="$S/runs.$sha.json"
        [ -f "$f" ] || nf
        emit <"$f"
        ;;
      *)
        [ -f "$S/api/$path.json" ] || nf
        emit <"$S/api/$path.json"
        ;;
    esac
    ;;
  pr)
    [ "$repo" = "$TAP" ] || bad "pr $sub without -R $TAP"
    d="$S/prs/$num"
    case "$sub" in
      list)
        for p in "$S"/prs/*
        do
          [ -f "$p/head" ] && [ "$(cat "$p/head")" = "$head" ] || continue
          [ "$state_f" != open ] || [ "$(cat "$p/state")" = OPEN ] || continue
          jq -n --argjson number "${p##*/}" --rawfile title "$p/title" --rawfile labels "$p/labels" \
            '{number: $number, title: $title, labels: ($labels | split("\n") | map(select(. != "") | {name: .}))}'
        done | jq -s . | emit
        ;;
      create)
        num=$(($(cat "$S/next_pr" 2>/dev/null || echo 41) + 1))
        echo "$num" >"$S/next_pr"
        d="$S/prs/$num"
        mkdir -p "$d"
        printf '%s' "$head" >"$d/head"
        printf '%s' "$title" >"$d/title"
        printf '%s' "$body" >"$d/body"
        : >"$d/labels"
        echo OPEN >"$d/state"
        echo "https://github.com/$TAP/pull/$num"
        ;;
      edit)
        [ -f "$d/head" ] || nf
        [ ! -f "$S/label.fail" ] || [ -z "$add_l$rm_l" ] || {
          echo "gh: could not add label: 'no-ticket' not found" >&2
          exit 1
        }
        [ ! -f "$S/title.fail" ] || [ -z "$title" ] || {
          echo "gh: GraphQL: could not update the pull request" >&2
          exit 1
        }
        [ -z "$title" ] || printf '%s' "$title" >"$d/title"
        [ -z "$body" ] || printf '%s' "$body" >"$d/body"
        [ -z "$add_l" ] || grep -qxF "${add_l%"$nl"}" "$d/labels" || printf '%s' "$add_l" >>"$d/labels"
        [ -z "$rm_l" ] || {
          grep -vixF -f <(printf '%s' "$rm_l") "$d/labels" >"$d/labels.new" 2>/dev/null
          mv "$d/labels.new" "$d/labels"
        }
        echo "https://github.com/$TAP/pull/$num"
        ;;
      view)
        [ -f "$d/head" ] || nf
        views=$(($(cat "$d/views" 2>/dev/null || echo 0) + 1))
        echo "$views" >"$d/views"
        [ ! -f "$S/move_to" ] || [ "$views" -lt 2 ] || {
          g update-ref "refs/heads/$(cat "$d/head")" "$(cat "$S/move_to")"
          rm "$S/move_to"
        }
        state="$(cat "$d/state")"
        [ ! -f "$S/view_state" ] || state="$(cat "$S/view_state")"
        oid="$(g rev-parse -q --verify "refs/heads/$(cat "$d/head")" || echo gone)"
        # The first view after a push can still name the branch's previous head.
        [ ! -f "$S/stale_head" ] || [ "$views" -gt 1 ] || oid="$(cat "$S/stale_head")"
        jq -n --arg state "$state" --arg mss "$(cat "$S/view_mss" 2>/dev/null || echo CLEAN)" --arg oid "$oid" \
          '{state: $state, headRefOid: $oid, mergeStateStatus: $mss}' | emit
        ;;
      merge)
        [ -f "$d/head" ] || nf
        $squash && $del || bad "merge without --squash --delete-branch"
        [ "$match" = "$(g rev-parse -q --verify "refs/heads/$(cat "$d/head")")" ] || {
          echo "gh: Head branch was modified. Review and try the merge again. (HTTP 409)" >&2
          exit 1
        }
        echo MERGED >"$d/state"
        g update-ref -d "refs/heads/$(cat "$d/head")"
        ;;
      *) bad "unexpected pr $sub" ;;
    esac
    ;;
  *) bad "unexpected $cmd" ;;
esac
STUB
  chmod +x "$1"
}

new_rig() {
  rigs=$((rigs + 1))
  R="${work}/rig${rigs}"
  mkdir -p "${R}/bin" "${R}/gh/api" "${R}/gh/assets" "${R}/gh/prs" "${R}/seed/Formula" "${R}/seed/Casks" "${R}/seed/scripts"
  : >"${R}/gh/log"
  write_stub "${R}/bin/gh"
  formula_text 1.2.2 111 "${ONES}" >"${R}/seed/Formula/demo.rb"
  cask_text 0.1.0 222 "${ONES}" >"${R}/seed/Casks/democask.rb"
  cp "${root}/scripts/bump.sh" "${R}/seed/scripts/bump.sh"
  cp "${root}/scripts/source-check.pl" "${R}/seed/scripts/source-check.pl"
  git -C "${R}/seed" init -q
  git -C "${R}/seed" add -A
  git -C "${R}/seed" commit -q -m seed
  git clone -q --bare "${R}/seed" "${R}/remote.git"
  git clone -q --depth=1 "file://${R}/remote.git" "${R}/tap"
}

# A second, full clone, for pushing what a human or a merge would.
other_clone() {
  rm -rf "${R}/other"
  git clone -q "file://${R}/remote.git" "${R}/other"
}

# Move the rig's clone to origin's current main, as a caller's fresh clone is.
refresh_clone() {
  rm -rf "${R}/tap"
  git clone -q --depth=1 "file://${R}/remote.git" "${R}/tap"
}

# add_release <owner/repo> <tag> <asset id> <asset name> [--no-sidecar]
#   [--no-digest] [--bad-sidecar] [--bad-digest] [--bad-size] [--state <s>]
#   [--also <another asset name>] [--bytes <file>: the asset's bytes]. Sets
#   $rel_sha to the asset's sha256.
add_release() {
  local repo="$1" tag="$2" id="$3" asset="$4" sidecar=true digest=true bad_sidecar=false bad_digest=false
  local bad_size=false state=uploaded also="" size assets side bytes=""
  shift 4
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      --no-sidecar) sidecar=false ;;
      --no-digest) digest=false ;;
      --bad-sidecar) bad_sidecar=true ;;
      --bad-digest) bad_digest=true ;;
      --bad-size) bad_size=true ;;
      --state)
        state="$2"
        shift
        ;;
      --also)
        also="$2"
        shift
        ;;
      --bytes)
        bytes="$2"
        shift
        ;;
    esac
    shift
  done
  if [[ -n "${bytes}" ]]
  then
    cp "${bytes}" "${R}/gh/assets/${id}"
  else
    printf 'the bytes of %s %s asset %s\n' "${repo}" "${tag}" "${id}" >"${R}/gh/assets/${id}"
  fi
  rel_sha="$(hash_of "${R}/gh/assets/${id}")"
  size="$(wc -c <"${R}/gh/assets/${id}" | tr -d ' ')"
  if ${bad_size}; then size=$((size + 1)); fi
  local dig=""
  if ${digest}; then dig="sha256:${rel_sha}"; fi
  if ${bad_digest}; then dig="sha256:${ZERO}"; fi
  assets="$(jq -n --argjson id "${id}" --arg name "${asset}" --argjson size "${size}" --arg state "${state}" --arg dig "${dig}" \
    '[{id: $id, name: $name, size: $size, state: $state, digest: (if $dig == "" then null else $dig end)},
      {id: 7, name: "demo_linux_amd64.tar.gz", size: 1, state: "uploaded", digest: null}]')"
  if ${sidecar}
  then
    side="${rel_sha}"
    if ${bad_sidecar}; then side="${ZERO}"; fi
    printf '%s  %s\n' "${side}" "${asset}" >"${R}/gh/assets/$((id + 1))"
    assets="$(jq --argjson id "$((id + 1))" --arg name "${asset}.sha256" '. + [{id: $id, name: $name, size: 99, state: "uploaded"}]' <<<"${assets}")"
  fi
  if [[ -n "${also}" ]]
  then
    assets="$(jq --arg name "${also}" '. + [{id: 9, name: $name, size: 1, state: "uploaded"}]' <<<"${assets}")"
  fi
  mkdir -p "${R}/gh/api/repos/${repo}/releases/tags"
  jq -n --argjson assets "${assets}" '{assets: $assets}' >"${R}/gh/api/repos/${repo}/releases/tags/${tag}.json"
}

# set_runs "<workflow file> <status> <conclusion>"...: this head's runs, plus an
# older failed run of each and a failed push run, which the gate must ignore.
set_runs() { # [--for <sha>] <line>...
  local f="${R}/gh/runs.json" wf status concl id=100 runs='[]'
  if [[ "$1" = --for ]]
  then
    f="${R}/gh/runs.$2.json"
    shift 2
  fi
  for line in "$@"
  do
    read -r wf status concl <<<"${line}"
    id=$((id + 10))
    runs="$(jq --arg p ".github/workflows/${wf}" --arg s "${status}" --arg c "${concl}" --argjson id "${id}" '. + [
      {id: ($id - 5), path: $p, event: "pull_request", status: "completed", conclusion: "failure"},
      {id: ($id + 1000), path: $p, event: "push", status: "completed", conclusion: "failure"},
      {id: $id, path: $p, event: "pull_request", status: $s, conclusion: (if $c == "-" then null else $c end)}]' <<<"${runs}")"
  done
  jq -n --argjson runs "${runs}" '{total_count: ($runs | length), workflow_runs: $runs}' >"${f}"
}
ALL_GREEN=("bump.yml completed success" "formulae.yml completed success" "secret-scan.yml completed success")

# collect <exit code>: sets code, and out (exact) and err from $R/out and $R/err.
collect() {
  code="$1"
  out="$(
    cat "${R}/out"
    printf .
  )"
  out="${out%.}"
  err="$(cat "${R}/err")"
}

# bump <args...>: runs the rig clone's bump.sh from outside it, as a caller's
# `pr="$("$tap/scripts/bump.sh" ...)"` does.
bump() {
  (cd "${R}" && PATH="${R}/bin:${PATH}" FAKE_GH="${R}/gh" FAKE_REMOTE="${R}/remote.git" \
    BUMP_POLL_SECONDS=0 BUMP_POLL_BUDGET="${BUDGET:-5}" "${sut_bash}" "${R}/tap/scripts/bump.sh" "$@") \
    >"${R}/out" 2>"${R}/err"
  collect $?
}

# bump_bare <args...>: bump.sh with nothing but traps on PATH: any external tool
# it runs is logged to $work/traps.log and fails.
bump_bare() {
  : >"${work}/traps.log"
  (cd "${R}" && env -i PATH="${work}/traps" TRAP_LOG="${work}/traps.log" "${sut_bash}" "${R}/tap/scripts/bump.sh" "$@") \
    >"${R}/out" 2>"${R}/err"
  collect $?
}
no_tools() { [[ ! -s "${work}/traps.log" ]]; }
mkdir -p "${work}/traps"
for tool in gh git perl sha256sum shasum cat sed awk grep mktemp rm cp mv diff jq ls sleep dirname basename
do
  printf '#!/bin/sh\necho "%s $*" >>"$TRAP_LOG"\nexit 91\n' "${tool}" >"${work}/traps/${tool}"
  chmod +x "${work}/traps/${tool}"
done

remote() { git --git-dir="${R}/remote.git" "$@"; }
tip_of() { remote rev-parse -q --verify "refs/heads/$1" || true; }
pr_field() { cat "${R}/gh/prs/$1/$2" 2>/dev/null; }
# The line of the last gh call logged whose arguments start with $1, a fixed
# string (0: none).
log_line() { awk -v p="$1" 'index($0, p) == 1 { n = NR } END { print n + 0 }' "${R}/gh/log"; }
clone_on_main() {
  [[ "$(git -C "${R}/tap" symbolic-ref -q HEAD)" = refs/heads/main ]] &&
    [[ -z "$(git -C "${R}/tap" status --porcelain)" ]] &&
    [[ -z "$(git -C "${R}/tap" branch --list 'bump/*')" ]]
}
# The bump branch is one commit ahead of main, changing only the three lines.
bumper_shaped() { # <branch> <version> <asset id> <sha256> [<entry path>]
  local path="${5:-Formula/demo.rb}" changed
  [[ "$(remote rev-list --count "main..$1")" = 1 ]] || return 1
  [[ "$(remote diff --name-only "main...$1")" = "${path}" ]] || return 1
  changed="$(remote diff -U0 "main...$1" | grep -E '^[-+] ' | grep -c -v -E '^[-+] +(version|url|sha256) ')"
  [[ "${changed}" = 0 ]] || return 1
  remote show "$1:${path}" | grep -q "version \"$2\"" &&
    remote show "$1:${path}" | grep -q "releases/assets/$3\"" &&
    remote show "$1:${path}" | grep -q "sha256 \"$4\""
}

# --- tests -------------------------------------------------------------------

new_rig

begin "I12: help does no work"
for args in "--help" "-h" "help" "demo v1.2.3 --help" "--dry-run help" "--ticket STARK-1 -h demo v1.2.3"
do
  # shellcheck disable=SC2086 # the cases are word lists
  bump_bare ${args}
  check "'${args}' exits 0 with usage on stdout and runs no tool" \
    eval 'is_code 0 && has "$out" "Usage: scripts/bump.sh" && [ -z "$err" ] && no_tools'
done
bump_bare --help
for wf in $(cd "${R}/tap" && bash -c '. scripts/bump.sh; echo "$GATE_WORKFLOWS"')
do
  check "--help names the gate's ${wf}" has "${out}" "${wf%.yml}"
done
bump_bare --ticket help demo v1.2.3
check "help as --ticket's value is data, not help" eval 'is_code 2 && [ -z "$out" ] && no_tools'
bump_bare --dry-run -- demo help
check "help after -- is a tag, and refused as one" eval 'is_code 2 && [ -z "$out" ] && stderr_has "invalid tag help" && no_tools'

begin "usage errors exit 2 before any tool or network call"
usage_cases=(
  "demo not-a-tag --dry-run" "demo v1.2 --dry-run" "demo v1.2.3.4" "demo v1.2.3 --ticket stark-1"
  "demo v1.2.3 --merge --dry-run" "demo v1.2.3 --no-pr --merge" "demo v1.2.3 --push" "demo"
  "demo v1.2.3 extra" "demo v1.2.3 --ticket" "demo v1.2.3 --asset-suffix a/b" "../demo v1.2.3"
)
for args in "${usage_cases[@]}"
do
  # shellcheck disable=SC2086 # the cases are word lists
  bump_bare ${args}
  check "'${args}'" eval 'is_code 2 && [ -z "$out" ] && no_tools'
done

begin "a missing or ambiguous entry exits 1 before any tool or network call"
bump_bare no-such-entry v0.0.1 --dry-run
check "no-such-entry names the entry" eval 'is_code 1 && [ -z "$out" ] && stderr_has "no tap entry no-such-entry" && no_tools'
cp "${R}/tap/Formula/demo.rb" "${R}/tap/Casks/demo.rb"
bump_bare demo v1.2.3 --dry-run
check "Formula/demo.rb beside Casks/demo.rb is ambiguous" eval 'is_code 1 && stderr_has "ambiguous" && no_tools'
rm "${R}/tap/Casks/demo.rb"
mkdir -p "${R}/tap/Casks/d"
cp "${R}/tap/Casks/democask.rb" "${R}/tap/Casks/d/democask.rb"
bump_bare democask v1.2.3 --dry-run
check "Casks/democask.rb beside Casks/d/democask.rb is ambiguous" eval 'is_code 1 && stderr_has "ambiguous" && stderr_has "Casks/d/democask.rb" && no_tools'
rm -r "${R}/tap/Casks/d"

begin "I1: --dry-run prints the diff to stderr and writes nothing"
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
echo '# operator note' >>"${R}/tap/Formula/demo.rb"
before="$(hash_of "${R}/tap/Formula/demo.rb")"
bump demo v1.2.3 --dry-run
check "exits 0 with empty stdout" eval 'is_code 0 && stdout_is ""'
check "the diff is on stderr" eval 'stderr_has "+  version \"1.2.3\"" && stderr_has "releases/assets/501\"," && stderr_has "+  sha256 \"$rel_sha\""'
check "the checkout's entry is byte-identical" eval '[ "$(hash_of "$R/tap/Formula/demo.rb")" = "$before" ]'
check "no branch, commit or PR" eval '[ -z "$(git -C "$R/tap" branch --list "bump/*")" ] && [ "$(gh_calls "pr ")" = 0 ] && [ -z "$(tip_of bump/demo-1.2.3)" ]'
check "I10: one release read, asset and sidecar downloaded by id" eval '[ "$(gh_calls "api repos/21StarkCom/demo/releases/tags/v1.2.3")" = 1 ] && [ "$(gh_calls "api -H Accept: application/octet-stream repos/21StarkCom/demo/releases/assets/501")" = 1 ] && [ "$(gh_calls "api -H Accept: application/octet-stream repos/21StarkCom/demo/releases/assets/502")" = 1 ]'
git -C "${R}/tap" checkout -q -- Formula/demo.rb
(cd "${R}/tap" && PATH="${R}/bin:${PATH}" FAKE_GH="${R}/gh" FAKE_REMOTE="${R}/remote.git" "${sut_bash}" scripts/bump.sh demo v1.2.3 --dry-run) >"${R}/out" 2>"${R}/err"
collect $?
check "a relative scripts/bump.sh from the tap's root works too" eval 'is_code 0 && stdout_is "" && stderr_has "+  version \"1.2.3\""'

begin "I5: the three lines must each occur once"
cp "${R}/tap/Formula/demo.rb" "${R}/demo.rb.orig"
printf '  version "9.9.9"\n' >>"${R}/tap/Formula/demo.rb"
bump demo v1.2.3 --dry-run
check "a second version line is refused" eval 'is_code 1 && stderr_has "want one version line, found 2"'
grep -v sha256 "${R}/demo.rb.orig" >"${R}/tap/Formula/demo.rb"
bump demo v1.2.3 --no-pr
check "a missing sha256 line is refused, and nothing is written" eval 'is_code 1 && stderr_has "want one sha256 line, found 0" && ! grep -q 1.2.3 "$R/tap/Formula/demo.rb"'
cp "${R}/demo.rb.orig" "${R}/tap/Formula/demo.rb"
sed 's#^  url "https://api.github.com/repos/21StarkCom/demo/#  url "https://api.github.com/repos/21StarkCom/other/#' "${R}/demo.rb.orig" >"${R}/tap/Formula/demo.rb"
printf '  url "https://api.github.com/repos/21StarkCom/demo/releases/assets/5"\n' >>"${R}/tap/Formula/demo.rb"
bump demo v1.2.3 --dry-run
check "two asset url lines are refused before any call" eval 'is_code 1 && stderr_has "want one release asset url line, found 2"'
cp "${R}/demo.rb.orig" "${R}/tap/Formula/demo.rb"

begin "I6, I10: the asset and its checksums"
# Each case is add_release's flags, a colon, then what bump.sh must say.
asset_cases=(
  "--also demo_v1.2.3_darwin_arm64.zip:exactly one *darwin_arm64.zip asset, found 2"
  "--bad-sidecar:.sha256 reads '${ZERO}'" "--bad-digest:GitHub's digest sha256:${ZERO} does not match"
  "--bad-size:the release lists" "--state starter:is not fully uploaded"
)
for case in "${asset_cases[@]}"
do
  : >"${R}/gh/log"
  # shellcheck disable=SC2086 # the flags are a word list
  add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip ${case%%:*}
  bump demo v1.2.3 --dry-run
  check "${case%%:*} is refused" eval 'is_code 1 && stdout_is "" && stderr_has "${case#*:}"'
done
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.tar.gz
bump demo v1.2.3 --dry-run
check "no asset with the suffix is refused" eval 'is_code 1 && stderr_has "exactly one *darwin_arm64.zip asset, found 0"'
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip --no-sidecar --no-digest
bump demo v1.2.3 --dry-run
check "with no sidecar and no digest, the downloaded bytes' hash is pinned" eval 'is_code 0 && stderr_has "+  sha256 \"$rel_sha\""'
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.tar.gz
bump --asset-suffix darwin_arm64.tar.gz --dry-run -- demo v1.2.3
check "--asset-suffix picks the tarball, with -- before the positionals" eval 'is_code 0 && stderr_has "releases/assets/501\","'
add_release 21StarkCom/democask desktop-v0.2.0 701 Democask-0.2.0.zip
bump democask desktop-v0.2.0 --asset-suffix .zip --dry-run
check "a cask, and a tag prefix other than v" eval 'is_code 0 && stderr_has "+  version \"0.2.0\"" && stderr_has "democask/releases/assets/701\","'
mkdir -p "${R}/tap/Casks/d"
git -C "${R}/tap" mv Casks/democask.rb Casks/d/democask.rb
bump democask desktop-v0.2.0 --asset-suffix .zip --dry-run
check "a cask in Casks/<first character>/, as Homebrew shards casks" eval 'is_code 0 && stderr_has "==> Casks/d/democask.rb:" && stderr_has "+  version \"0.2.0\""'
git -C "${R}/tap" mv Casks/d/democask.rb Casks/democask.rb

begin "I2: --no-pr edits this checkout's entry, with no commit and no PR"
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
head_before="$(git -C "${R}/tap" rev-parse HEAD)"
bump demo v1.2.3 --no-pr
check "exits 0 with empty stdout" eval 'is_code 0 && stdout_is ""'
check "the entry now pins the release" eval 'diff <(formula_text 1.2.3 501 "$rel_sha") "$R/tap/Formula/demo.rb" >/dev/null'
check "the comment naming releases/assets/999 is untouched" grep -q 'releases/assets/999 is not' "${R}/tap/Formula/demo.rb"
check "no commit and no PR" eval '[ "$(git -C "$R/tap" rev-parse HEAD)" = "$head_before" ] && [ "$(gh_calls "pr ")" = 0 ]'
git -C "${R}/tap" checkout -q -- Formula/demo.rb

begin "I3: a PR run needs a clean checkout at origin's main"
echo '# edit' >>"${R}/tap/Formula/demo.rb"
: >"${R}/gh/log"
bump demo v1.2.3
check "tracked edits are refused before the release is read" eval 'is_code 1 && stderr_has "tracked edits" && no_gh'
git -C "${R}/tap" checkout -q -- Formula/demo.rb
other_clone
echo docs >"${R}/other/NOTES"
git -C "${R}/other" add NOTES
git -C "${R}/other" commit -q -m notes
git -C "${R}/other" push -q origin main
bump demo v1.2.3
check "a HEAD behind origin's main is refused" eval 'is_code 1 && stderr_has "not origin'"'"'s main" && no_gh && [ -z "$(tip_of bump/demo-1.2.3)" ]'
refresh_clone

begin "a PR run: one bump commit on bump/<entry>-<version>, stdout the PR number"
main_before="$(tip_of main)"
bump demo v1.2.3 --ticket STARK-7
check "I9: stdout is the PR number and nothing else" eval 'is_code 0 && stdout_is "42$NL"'
check "the branch is main plus one commit changing only the three lines" bumper_shaped bump/demo-1.2.3 1.2.3 501 "${rel_sha}"
check "the commit subject carries the ticket and asset" eval '[ "$(remote log -1 --format=%s bump/demo-1.2.3)" = "chore(STARK-7): bump demo to v1.2.3 (asset 501)" ]'
check "the PR title and body" eval '[ "$(pr_field 42 title)" = "chore(STARK-7): bump demo to v1.2.3" ] && has "$(pr_field 42 body)" "asset \`501\`, sha256 \`$rel_sha\`"'
check "a --ticket PR opens with no label" eval '[ -z "$(pr_field 42 labels)" ] && [ "$(gh_calls "pr create")" = 1 ] && ! grep -q -- -label "${R}/gh/log"'
check "I13: main is untouched" eval '[ "$(tip_of main)" = "$main_before" ]'
check "I15: the checkout is back on main, clean, with no bump branch" clone_on_main

begin "a leftover local bump branch is reset from main, never switched to (I4)"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
git -C "${R}/tap" checkout -q -b bump/demo-1.2.3
echo junk >"${R}/tap/JUNK"
git -C "${R}/tap" add JUNK
git -C "${R}/tap" commit -q -m junk
git -C "${R}/tap" checkout -q main
bump demo v1.2.3
check "the pushed branch carries only the bump" eval 'is_code 0 && bumper_shaped bump/demo-1.2.3 1.2.3 501 "$rel_sha"'
check "the checkout is back on main" clone_on_main
refresh_clone
git -C "${R}/tap" checkout -q -b bump/demo-1.2.4
add_release 21StarkCom/demo v1.2.4 511 demo_v1.2.4_darwin_arm64.zip
bump demo v1.2.4
check "a run started on its own bump branch ends detached at main, with no bump branch" eval 'is_code 0 && [ "$(git -C "$R/tap" rev-parse HEAD)" = "$(tip_of main)" ] && [ -z "$(git -C "$R/tap" branch --list "bump/*")" ]'

begin "Decision 6: retry reuse"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3 --ticket STARK-7
first_tip="$(tip_of bump/demo-1.2.3)"
bump demo v1.2.3
check "an identical re-run reuses the branch as it stands, with no push" eval 'is_code 0 && stdout_is "42$NL" && [ "$(tip_of bump/demo-1.2.3)" = "$first_tip" ] && [ "$(gh_calls "pr create")" = 1 ] && stderr_has "reusing it as it stands"'
add_release 21StarkCom/demo v1.2.3 601 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
check "a re-uploaded asset rebuilds the branch from main and reuses PR #42" eval 'is_code 0 && stdout_is "42$NL" && bumper_shaped bump/demo-1.2.3 1.2.3 601 "$rel_sha" && [ "$(gh_calls "pr create")" = 1 ]'
check "the body is refreshed; the title keeps its scope without --ticket" eval 'has "$(pr_field 42 body)" "asset \`601\`" && [ "$(pr_field 42 title)" = "chore(STARK-7): bump demo to v1.2.3" ]'
check "a --ticket PR reused without --ticket gains no no-ticket label" eval '[ -z "$(pr_field 42 labels)" ]'
add_release 21StarkCom/demo v1.2.3 611 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3 --ticket STARK-8
check "--ticket retitles the reused PR" eval 'is_code 0 && [ "$(pr_field 42 title)" = "chore(STARK-8): bump demo to v1.2.3" ]'
other_clone
git -C "${R}/other" checkout -q bump/demo-1.2.3
sed -i.bak 's/bin.install "demo"/bin.install "demo", "demo-x"/' "${R}/other/Formula/demo.rb"
git -C "${R}/other" commit -q -a --amend --no-edit
git -C "${R}/other" push -q -f origin bump/demo-1.2.3
hand_tip="$(tip_of bump/demo-1.2.3)"
add_release 21StarkCom/demo v1.2.3 621 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
check "a hand edit amended into the one commit is refused, naming the PR" eval 'is_code 1 && stdout_is "" && stderr_has "PR #42" && [ "$(tip_of bump/demo-1.2.3)" = "$hand_tip" ] && clone_on_main'
git -C "${R}/other" checkout -q -B bump/demo-1.2.3 origin/main
formula_text 1.2.3 501 "${ONES}" >"${R}/other/Formula/demo.rb"
git -C "${R}/other" commit -q -a -m "bump by hand"
echo more >"${R}/other/NOTES"
git -C "${R}/other" add NOTES
git -C "${R}/other" commit -q -m "a second commit"
git -C "${R}/other" push -q -f origin bump/demo-1.2.3
hand_tip="$(tip_of bump/demo-1.2.3)"
bump demo v1.2.3
check "a branch two commits ahead is refused" eval 'is_code 1 && stderr_has "2 commits ahead" && [ "$(tip_of bump/demo-1.2.3)" = "$hand_tip" ]'

begin "no-ticket: the label follows the PR's final title"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
check "a run without --ticket labels its unscoped PR once it is open, with the retitle hint" eval 'is_code 0 && stdout_is "42$NL" && [ "$(pr_field 42 labels)" = no-ticket ] && [ "$(pr_field 42 title)" = "chore: bump demo to v1.2.3" ] && [ "$(log_line "pr create")" -gt 0 ] && [ "$(log_line "pr create")" -lt "$(log_line "pr edit 42 -R $TAP --add-label")" ] && stderr_has "--title '"'"'chore(STARK-<n>): bump demo to v1.2.3'"'"' --remove-label no-ticket"'
add_release 21StarkCom/demo v1.2.3 601 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
check "a re-run without --ticket keeps the one label, with no label call" eval 'is_code 0 && stdout_is "42$NL" && [ "$(pr_field 42 labels)" = no-ticket ] && [ "$(grep -c -- -label "$R/gh/log")" = 1 ]'
bump demo v1.2.3 --ticket STARK-9
check "--ticket retitles, then drops the label" eval 'is_code 0 && [ "$(pr_field 42 title)" = "chore(STARK-9): bump demo to v1.2.3" ] && [ -z "$(pr_field 42 labels)" ] && [ "$(log_line "pr edit 42 -R $TAP --title chore(STARK-9)")" -gt 0 ] && [ "$(log_line "pr edit 42 -R $TAP --title chore(STARK-9)")" -lt "$(log_line "pr edit 42 -R $TAP --remove-label")" ] && stderr_lacks "If a ticket covers this bump"'
: >"${R}/gh/log"
bump demo v1.2.3 --ticket STARK-9
check "--ticket on an unlabeled PR makes no label call" eval 'is_code 0 && ! grep -q -- -label "$R/gh/log"'
bump demo v1.2.3
check "a ticket-titled PR re-run without --ticket gains no label" eval 'is_code 0 && [ -z "$(pr_field 42 labels)" ]'

begin "no-ticket: a human's retitle, read with idun's title grammar"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
printf '%s' "chore(STARK-12): bump demo to v1.2.3" >"${R}/gh/prs/42/title"
bump demo v1.2.3
check "a re-run drops the label from a PR a human retitled to a ticket" eval 'is_code 0 && [ -z "$(pr_field 42 labels)" ] && [ "$(pr_field 42 title)" = "chore(STARK-12): bump demo to v1.2.3" ]'
for t in "chore(STARK-12)!: bump demo to v1.2.3" "chore(STARK-12):bump demo to v1.2.3" "  chore(ABC-3): bump demo to v1.2.3"
do
  printf '%s' "${t}" >"${R}/gh/prs/42/title"
  printf 'no-ticket\n' >"${R}/gh/prs/42/labels"
  bump demo v1.2.3
  check "idun reads '${t}' as ticket-titled, so the label goes" eval 'is_code 0 && [ -z "$(pr_field 42 labels)" ]'
done
printf '%s' "chore: bump demo to v1.2.3" >"${R}/gh/prs/42/title"
printf 'No-Ticket\n' >"${R}/gh/prs/42/labels"
: >"${R}/gh/log"
bump demo v1.2.3
check "a mark in another case counts, as idun counts it: no label call" eval 'is_code 0 && ! grep -q -- -label "$R/gh/log"'
bump demo v1.2.3 --ticket STARK-9
check "--ticket drops a mark in another case" eval 'is_code 0 && [ -z "$(pr_field 42 labels)" ] && [ "$(pr_field 42 title)" = "chore(STARK-9): bump demo to v1.2.3" ]'

begin "no-ticket: a failed label step"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
: >"${R}/gh/label.fail"
bump demo v1.2.3
check "a failed add is a warning naming the command: the PR is open and the run succeeds" eval 'is_code 0 && stdout_is "42$NL" && [ -z "$(pr_field 42 labels)" ] && stderr_has "could not label PR #42 no-ticket" && stderr_has "run: gh pr edit 42 -R $TAP --add-label no-ticket"'
rm "${R}/gh/label.fail"
bump demo v1.2.3
check "the next identical run labels it" eval 'is_code 0 && [ "$(pr_field 42 labels)" = no-ticket ]'
: >"${R}/gh/label.fail"
bump demo v1.2.3 --ticket STARK-9
check "a failed drop under --ticket still retitles, and warns with the command" eval 'is_code 0 && [ "$(pr_field 42 title)" = "chore(STARK-9): bump demo to v1.2.3" ] && [ "$(pr_field 42 labels)" = no-ticket ] && stderr_has "whose title names a ticket" && stderr_has "run: gh pr edit 42 -R $TAP --remove-label no-ticket"'
rm "${R}/gh/label.fail"
bump demo v1.2.3
check "the next run without --ticket drops it" eval 'is_code 0 && [ -z "$(pr_field 42 labels)" ]'
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
: >"${R}/gh/title.fail"
bump demo v1.2.3 --ticket STARK-9
check "a failed retitle under --ticket stops the run, the PR still unscoped AND marked" eval 'is_code 1 && stderr_has "could not retitle PR #42" && [ "$(pr_field 42 title)" = "chore: bump demo to v1.2.3" ] && [ "$(pr_field 42 labels)" = no-ticket ]'
rm "${R}/gh/title.fail"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
set_runs "${ALL_GREEN[@]}"
: >"${R}/gh/label.fail"
bump demo v1.2.3 --merge
check "--merge still merges when the label step fails, with no retitle hint" eval 'is_code 0 && stdout_is "42$NL" && [ "$(pr_field 42 state)" = MERGED ] && stderr_has "could not label PR #42" && stderr_lacks "If a ticket covers this bump"'

begin "main already carries the release: nothing to merge"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
other_clone
git -C "${R}/other" merge -q --ff-only origin/bump/demo-1.2.3
git -C "${R}/other" push -q origin main
refresh_clone
: >"${R}/gh/log"
bump demo v1.2.3 --merge
check "exits 0 with empty stdout, before touching any branch" eval 'is_code 0 && stdout_is "" && [ "$(gh_calls "pr ")" = 0 ] && stderr_has "already pins"'

begin "I11: a PR run never moves an entry to an older release"
new_rig
add_release 21StarkCom/demo v1.2.1 401 demo_v1.2.1_darwin_arm64.zip
bump demo v1.2.1
check "an older X.Y.Z opens nothing" eval 'is_code 0 && stdout_is "" && [ "$(gh_calls "pr ")" = 0 ] && [ -z "$(tip_of bump/demo-1.2.1)" ] && stderr_has "never moves an entry back"'
bump demo v1.2.1 --dry-run
check "--dry-run still previews it" eval 'is_code 0 && stderr_has "+  version \"1.2.1\""'
bump demo v1.2.1 --no-pr
check "--no-pr still stages it" eval 'is_code 0 && grep -q "version \"1.2.1\"" "$R/tap/Formula/demo.rb"'
git -C "${R}/tap" checkout -q -- Formula/demo.rb
add_release 21StarkCom/demo v1.2.2-rc.1 411 demo_v1.2.2-rc.1_darwin_arm64.zip
bump demo v1.2.2-rc.1
check "the same core with a pre-release is not older" eval 'is_code 0 && stdout_is "42$NL" && bumper_shaped bump/demo-1.2.2-rc.1 1.2.2-rc.1 411 "$rel_sha"'
add_release 21StarkCom/demo cli-v1.3.0 421 brain_1.3.0_darwin_arm64.zip
bump demo cli-v1.3.0
check "a cli-v tag names the branch by version and the title by tag" eval 'is_code 0 && bumper_shaped bump/demo-1.3.0 1.3.0 421 "$rel_sha" && [ "$(pr_field 43 title)" = "chore: bump demo to cli-v1.3.0" ]'

begin "I14, Decision 4: --merge"
new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
set_runs "${ALL_GREEN[@]}"
bump demo v1.2.3 --merge
check "every named workflow green: squash-merged, pinned to the head it read" eval 'is_code 0 && stdout_is "42$NL" && [ "$(pr_field 42 state)" = MERGED ] && grep -q "^pr merge 42 -R $TAP --squash --delete-branch --match-head-commit [0-9a-f]\{40\}$" "$R/gh/log"'
check "the merged branch is deleted" eval '[ -z "$(tip_of bump/demo-1.2.3)" ]'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
set_runs "bump.yml completed success" "formulae.yml completed failure" "secret-scan.yml completed success"
BUDGET=50 bump demo v1.2.3 --merge
check "a failed run fails at once, replaying the reading" eval 'is_code 1 && stdout_is "42$NL" && [ "$(gh_calls "pr view")" = 1 ] && [ "$(gh_calls "pr merge")" = 0 ] && stderr_has "formulae.yml: completed failure" && stderr_has "did not succeed"'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
set_runs "formulae.yml completed success" "secret-scan.yml completed success"
BUDGET=3 bump demo v1.2.3 --merge
check "a workflow with no run waits out the budget, naming it missing" eval 'is_code 1 && [ "$(gh_calls "pr view")" = 3 ] && [ "$(gh_calls "pr merge")" = 0 ] && stderr_has "bump.yml: missing" && stderr_has "after 3 polls"'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
touch "${R}/gh/runs.403"
BUDGET=50 bump demo v1.2.3 --merge
check "no Actions: read fails at once, naming the permission" eval 'is_code 1 && [ "$(gh_calls "pr view")" = 1 ] && [ "$(gh_calls "pr merge")" = 0 ] && stderr_has "Actions: read"'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
touch "${R}/gh/runs.ratelimit"
BUDGET=3 bump demo v1.2.3 --merge
check "a rate-limited 403 is retried, not read as a missing Actions: read" eval 'is_code 1 && [ "$(gh_calls "pr view")" = 3 ] && [ "$(gh_calls "pr merge")" = 0 ] && stderr_has "rate limit exceeded" && stderr_lacks "without Actions: read" && stderr_has "after 3 polls"'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
bump demo v1.2.3
old_head="$(tip_of bump/demo-1.2.3)"
set_runs --for "${old_head}" "bump.yml completed success" "formulae.yml completed failure" "secret-scan.yml completed success"
set_runs "${ALL_GREEN[@]}"
add_release 21StarkCom/demo v1.2.3 601 demo_v1.2.3_darwin_arm64.zip
echo "${old_head}" >"${R}/gh/stale_head"
BUDGET=5 bump demo v1.2.3 --merge
check "a first reading still on the previous head is not gated: the pushed head merges" eval 'is_code 0 && stdout_is "42$NL" && stderr_has "not the pushed" && stderr_lacks "did not succeed" && [ "$(gh_calls "pr merge")" = 1 ] && ! grep -q "match-head-commit $old_head" "$R/gh/log"'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
set_runs "${ALL_GREEN[@]}"
echo CLOSED >"${R}/gh/view_state"
BUDGET=50 bump demo v1.2.3 --merge
check "a closed PR fails at once" eval 'is_code 1 && [ "$(gh_calls "pr merge")" = 0 ] && stderr_has "is closed"'
echo MERGED >"${R}/gh/view_state"
bump demo v1.2.3 --merge
check "a PR already merged ends the wait as success" eval 'is_code 0 && stdout_is "42$NL" && [ "$(gh_calls "pr merge")" = 0 ]'
rm "${R}/gh/view_state"
echo DIRTY >"${R}/gh/view_mss"
BUDGET=50 bump demo v1.2.3 --merge
check "a conflict on the gated head fails at once" eval 'is_code 1 && [ "$(gh_calls "pr merge")" = 0 ] && stderr_has "conflicts with main"'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
# A concurrent retry's rebuild: the bumper's own shape, another asset.
other_clone
formula_text 1.2.3 777 "${ONES}" >"${R}/other/Formula/demo.rb"
git -C "${R}/other" commit -q -a -m "a concurrent rebuild"
git -C "${R}/other" push -q origin HEAD:refs/heads/scratch
moved="$(tip_of scratch)"
echo "${moved}" >"${R}/gh/move_to"
set_runs "bump.yml in_progress -" "formulae.yml completed success" "secret-scan.yml completed success"
set_runs --for "${moved}" "${ALL_GREEN[@]}"
BUDGET=10 bump demo v1.2.3 --merge
check "a head that moves to another bumper commit restarts the gate on it" eval 'is_code 0 && stderr_has "head moved to $moved" && grep -q "match-head-commit $moved$" "$R/gh/log" && [ "$(gh_calls "pr merge")" = 1 ]'

new_rig
add_release 21StarkCom/demo v1.2.3 501 demo_v1.2.3_darwin_arm64.zip
other_clone
echo "a human's edit" >"${R}/other/NOTES"
git -C "${R}/other" add NOTES
git -C "${R}/other" commit -q -m "a human's edit"
git -C "${R}/other" push -q origin HEAD:refs/heads/scratch
moved="$(tip_of scratch)"
echo "${moved}" >"${R}/gh/move_to"
set_runs "bump.yml in_progress -" "formulae.yml completed success" "secret-scan.yml completed success"
set_runs --for "${moved}" "${ALL_GREEN[@]}"
BUDGET=10 bump demo v1.2.3 --merge
check "a head that moves to a human's edit is never merged unattended" eval 'is_code 1 && stderr_has "not merging a human" && [ "$(gh_calls "pr merge")" = 0 ] && [ "$(gh_calls "pr view")" = 2 ]'

# --- public entries (docs/specs/public-tap.md) ---------------------------------

PUB_DL="https://github.com/${TAP}/releases/download"
# A public entry: its url is a public release of the tap, and a comment names its
# source repo. <version> <asset name> <sha256>
pub_text() {
  printf '%s\n' \
    'class Pubdemo < Formula' \
    '  desc "Pubdemo"' \
    '  homepage "https://github.com/21StarkCom/homebrew-tap"' \
    '  # Source release repo: 21StarkCom/pubdemo' \
    "  url \"${PUB_DL}/pubdemo-v$1/$2\"" \
    "  version \"$1\"" \
    "  sha256 \"$3\"" \
    'end'
}
# Zips its arguments, path=text pairs, into $1 with Perl's core zip module.
zip_of() { # <zip> <path=text>...
  local out="$1"
  shift
  perl -MIO::Compress::Zip=zip,\$ZipError -e '
    my $out = shift @ARGV;
    my $z = IO::Compress::Zip->new($out) or die $ZipError;
    for (@ARGV) { my ($n, $t) = split /=/, $_, 2; $z->newStream(Name => $n); $z->print($t) }
    $z->close' "${out}" "$@"
}
# A rig whose tap also holds Formula/pubdemo.rb at 1.0.0.
pub_rig() {
  new_rig
  other_clone
  pub_text 1.0.0 pubdemo_1.0.0_darwin_arm64.zip "${ONES}" >"${R}/other/Formula/pubdemo.rb"
  git -C "${R}/other" add -A
  git -C "${R}/other" commit -qm "pubdemo"
  git -C "${R}/other" push -q origin HEAD:main
  refresh_clone
  zip_of "${work}/clean.zip" "pubdemo=binary bytes" "share/readme.txt=hello"
}
released() { [[ -f "${R}/gh/api/repos/${TAP}/releases/tags/$1.json" ]]; }
pinned_line() { grep -qxF "$2" "${R}/tap/$1" || remote show "main:$1" | grep -qxF "$2"; }

begin "a public entry: --dry-run publishes nothing"
pub_rig
add_release 21StarkCom/pubdemo v1.1.0 601 pubdemo_1.1.0_darwin_arm64.zip --bytes "${work}/clean.zip"
bump pubdemo v1.1.0 --dry-run
check "exit 0" is_code 0
check "previews the public url" stderr_has "+  url \"${PUB_DL}/pubdemo-v1.1.0/pubdemo_1.1.0_darwin_arm64.zip\""
check "says what it would publish" stderr_has "would publish pubdemo_1.1.0_darwin_arm64.zip as the release pubdemo-v1.1.0"
check "runs the source check" stderr_has "checking pubdemo_1.1.0_darwin_arm64.zip for source"
check "makes no release" eval '[ "$(gh_calls "api -X POST")" = 0 ] && [ "$(gh_calls "api -X PATCH")" = 0 ]'

begin "a public entry: a PR run publishes the release, then pins it"
: >"${R}/gh/log"
bump pubdemo v1.1.0 --ticket STARK-9
check "exit 0, stdout the PR number" eval 'is_code 0 && stdout_is "42$NL"'
check "reads the source release of 21StarkCom/pubdemo" eval '[ "$(gh_calls "api repos/21StarkCom/pubdemo/releases/tags/v1.1.0")" = 1 ]'
check "makes a draft release pubdemo-v1.1.0" eval 'grep -qx "draft=true" "$R/gh/rel/901.fields" && grep -qx "tag_name=pubdemo-v1.1.0" "$R/gh/rel/901.fields"'
check "uploads the asset under its own name" eval 'grep -q "^5001 pubdemo_1.1.0_darwin_arm64.zip$" "$R/gh/rel/901.assets" && cmp -s "$R/gh/assets/5001" "$work/clean.zip"'
check "publishes the release" released pubdemo-v1.1.0
check "publishes before it pushes" eval '[ "$(log_line "api -X PATCH repos/$TAP/releases/901")" -lt "$(log_line "pr create")" ]'
check "the branch is main plus one bumper commit" eval '[ "$(remote rev-list --count main..bump/pubdemo-1.1.0)" = 1 ] && [ "$(remote diff --name-only main...bump/pubdemo-1.1.0)" = Formula/pubdemo.rb ]'
check "it pins the public url" eval 'remote show bump/pubdemo-1.1.0:Formula/pubdemo.rb | grep -qxF "  url \"${PUB_DL}/pubdemo-v1.1.0/pubdemo_1.1.0_darwin_arm64.zip\""'
check "it pins the version and sha256" eval 'remote show bump/pubdemo-1.1.0:Formula/pubdemo.rb | grep -qxF "  version \"1.1.0\"" && remote show bump/pubdemo-1.1.0:Formula/pubdemo.rb | grep -qxF "  sha256 \"$rel_sha\""'
check "it keeps the source line" eval 'remote show bump/pubdemo-1.1.0:Formula/pubdemo.rb | grep -qxF "  # Source release repo: 21StarkCom/pubdemo"'
check "the PR body names the release" eval 'has "$(pr_field 42 body)" "published as the release \`pubdemo-v1.1.0\` of this tap"'
check "I15: the checkout is back on main" clone_on_main

begin "a public entry: a rerun reuses the release"
: >"${R}/gh/log"
bump pubdemo v1.1.0 --ticket STARK-9
check "exit 0" is_code 0
check "makes and uploads nothing" eval '[ "$(gh_calls "api -X POST")" = 0 ] && [ "$(gh_calls "api -X PATCH")" = 0 ]'
check "says it reuses it" stderr_has "release pubdemo-v1.1.0 already holds pubdemo_1.1.0_darwin_arm64.zip; reusing it"
check "reuses the PR" stderr_has "reusing PR #42"

begin "a public entry: main already pins it, and its release is there"
other_clone
git -C "${R}/other" merge -q --ff-only origin/bump/pubdemo-1.1.0
git -C "${R}/other" push -q origin main
refresh_clone
: >"${R}/gh/log"
bump pubdemo v1.1.0
check "exit 0, nothing to do" eval 'is_code 0 && stdout_is "" && stderr_has "already pins"'
check "checks the release, and makes nothing" eval '[ "$(gh_calls "api repos/$TAP/releases/tags/pubdemo-v1.1.0")" = 1 ] && [ "$(gh_calls "api -X POST")" = 0 ]'

begin "a public entry: --merge gates the bump as any other"
pub_rig
add_release 21StarkCom/pubdemo v1.1.0 601 pubdemo_1.1.0_darwin_arm64.zip --bytes "${work}/clean.zip"
set_runs "${ALL_GREEN[@]}"
bump pubdemo v1.1.0 --merge
check "publishes, then merges the bumper's own commit" eval 'is_code 0 && released pubdemo-v1.1.0 && [ "$(pr_field 42 state)" = MERGED ]'

begin "a public entry: other bytes under the asset's name stop the run"
pub_rig
add_release 21StarkCom/pubdemo v1.1.0 601 pubdemo_1.1.0_darwin_arm64.zip --bytes "${work}/clean.zip"
mkdir -p "${R}/gh/api/repos/${TAP}/releases/tags"
jq -n --arg d "sha256:${ZERO}" '{id: 77, assets: [{id: 78, name: "pubdemo_1.1.0_darwin_arm64.zip", state: "uploaded", digest: $d}]}' \
  >"${R}/gh/api/repos/${TAP}/releases/tags/pubdemo-v1.1.0.json"
bump pubdemo v1.1.0
check "exit 1" is_code 1
check "says it never replaces a public asset" stderr_has "a public asset is never replaced"
check "uploads nothing and opens no PR" eval '[ "$(gh_calls "api -X POST")" = 0 ] && [ "$(gh_calls "pr create")" = 0 ]'

begin "a public entry: a published release without the asset gets it"
rm "${R}/gh/api/repos/${TAP}/releases/tags/pubdemo-v1.1.0.json"
mkdir -p "${R}/gh/rel"
printf 'pubdemo-v1.1.0' >"${R}/gh/rel/77.tag"
: >"${R}/gh/rel/77.assets"
jq -n '{id: 77, assets: []}' >"${R}/gh/api/repos/${TAP}/releases/tags/pubdemo-v1.1.0.json"
: >"${R}/gh/log"
bump pubdemo v1.1.0 --no-pr
check "exit 0" is_code 0
check "uploads to that release, with no new draft" eval '[ "$(gh_calls "api -X POST repos/$TAP/releases")" = 0 ] && grep -q "pubdemo_1.1.0_darwin_arm64.zip" "$R/gh/rel/77.assets"'
check "publishes nothing more" eval '[ "$(gh_calls "api -X PATCH")" = 0 ]'
check "--no-pr pins the public url in the checkout" pinned_line Formula/pubdemo.rb "  url \"${PUB_DL}/pubdemo-v1.1.0/pubdemo_1.1.0_darwin_arm64.zip\""
git -C "${R}/tap" checkout -q -- Formula/pubdemo.rb

begin "a public entry: an upload that reads back wrong is not published"
pub_rig
add_release 21StarkCom/pubdemo v1.1.0 601 pubdemo_1.1.0_darwin_arm64.zip --bytes "${work}/clean.zip"
: >"${R}/gh/upload.bad"
bump pubdemo v1.1.0
check "exit 1" is_code 1
check "says the digest is wrong" stderr_has "reads back as sha256:${ZERO}"
check "publishes nothing and opens no PR" eval '[ "$(gh_calls "api -X PATCH")" = 0 ] && [ "$(gh_calls "pr create")" = 0 ] && ! released pubdemo-v1.1.0'
rm "${R}/gh/upload.bad"

begin "a public entry: an upload with no digest is downloaded and hashed"
: >"${R}/gh/upload.nodigest"
: >"${R}/gh/log"
bump pubdemo v1.1.0 --no-pr
check "exit 0" is_code 0
check "downloads the upload to hash it" eval '[ "$(gh_calls "api -H Accept: application/octet-stream repos/$TAP/releases/assets/")" = 1 ]'
check "publishes it" released pubdemo-v1.1.0
rm "${R}/gh/upload.nodigest"
git -C "${R}/tap" checkout -q -- Formula/pubdemo.rb

begin "a public entry: an asset with source is not published"
pub_rig
zip_of "${work}/source.zip" "pubdemo=binary bytes" "dist/app.js.map={}"
add_release 21StarkCom/pubdemo v1.1.0 601 pubdemo_1.1.0_darwin_arm64.zip --bytes "${work}/source.zip"
bump pubdemo v1.1.0
check "exit 1" is_code 1
check "names the file and why" stderr_has "dist/app.js.map: a source map"
check "makes no release and opens no PR" eval '[ "$(gh_calls "api -X POST")" = 0 ] && [ "$(gh_calls "pr create")" = 0 ]'
bump pubdemo v1.1.0 --dry-run
check "--dry-run refuses it too" is_code 1
printf 'not an archive\n' >"${work}/plain.bin"
add_release 21StarkCom/pubdemo v1.1.1 611 pubdemo_1.1.1_darwin_arm64.zip --bytes "${work}/plain.bin"
bump pubdemo v1.1.1
check "an asset the check cannot read: exit 1" is_code 1
check "says the check did not run" stderr_has "the source check of pubdemo_1.1.1_darwin_arm64.zip did not run"

# Packs path=text pairs into a flat .pkg, as pkgbuild makes one: a xar archive of a
# gzip odc Payload. <pkg> <path=text>...
pkg_of() {
  local out="$1" dir="${work}/pkg" pair
  shift
  rm -rf "${dir}"
  mkdir -p "${dir}/root" "${dir}/flat"
  for pair in "$@"
  do
    mkdir -p "${dir}/root/${pair%/*}"
    printf '%s' "${pair#*=}" >"${dir}/root/${pair%%=*}"
  done
  bsdtar --format odc -czf "${dir}/flat/Payload" -C "${dir}/root" .
  printf '<pkg-info/>\n' >"${dir}/flat/PackageInfo"
  bsdtar --format xar -cf "${out}" -C "${dir}/flat" .
}

if [[ -n "${BUMP_TEST_SKIP_PKG:-}" ]]
then
  printf '\n# a public entry: a .pkg asset\nskip BUMP_TEST_SKIP_PKG is set\n'
else
  begin "a public entry: a .pkg asset"
  pub_rig
  pkg_of "${work}/clean.pkg" "usr/local/bin/pubdemo=binary bytes"
  add_release 21StarkCom/pubdemo v1.2.0 621 pubdemo-1.2.0.pkg --bytes "${work}/clean.pkg"
  bump pubdemo v1.2.0 --no-pr --asset-suffix .pkg
  check "a clean .pkg: exit 0" is_code 0
  check "a clean .pkg: publishes it" released pubdemo-v1.2.0
  check "a clean .pkg: pins its url" pinned_line Formula/pubdemo.rb "  url \"${PUB_DL}/pubdemo-v1.2.0/pubdemo-1.2.0.pkg\""
  git -C "${R}/tap" checkout -q -- Formula/pubdemo.rb
  pkg_of "${work}/source.pkg" "usr/local/bin/pubdemo=binary bytes" "usr/local/lib/pubdemo/main.ts=export {}"
  add_release 21StarkCom/pubdemo v1.2.1 631 pubdemo-1.2.1.pkg --bytes "${work}/source.pkg"
  : >"${R}/gh/log"
  bump pubdemo v1.2.1 --no-pr --asset-suffix .pkg
  check "a .pkg with source: exit 1" is_code 1
  check "a .pkg with source: names the file" stderr_has "usr/local/lib/pubdemo/main.ts:"
  check "a .pkg with source: makes no release" eval '[ "$(gh_calls "api -X POST")" = 0 ] && ! released pubdemo-v1.2.1'
fi

begin "a public entry needs one source line"
pub_rig
other_clone
perl -ni -e 'print unless /Source release repo/' "${R}/other/Formula/pubdemo.rb"
git -C "${R}/other" commit -qam "no source line" && git -C "${R}/other" push -q origin HEAD:main
refresh_clone
: >"${R}/gh/log"
bump pubdemo v1.1.0 --dry-run
check "exit 1 before any gh call" eval 'is_code 1 && no_gh'
check "says what it needs" stderr_has "a public entry needs one '# Source release repo: <owner>/<repo>' line, found 0"

begin "every entry in this tap has the bumper's three lines, once each"
for path in "${root}"/Formula/*.rb "${root}"/Casks/*.rb "${root}"/Casks/*/*.rb
do
  [[ -f "${path}" ]] || continue # a glob with no match stays as its pattern
  entry_rel="${path#"${root}"/}"
  result="$(cd "${root}" && ENTRY_REL="${entry_rel}" OUT="${work}/rewritten.rb" bash -c '
    . scripts/bump.sh
    tap_root=$PWD rel=$ENTRY_REL version=9.9.9 a_id=123 sha='"${ONES}"'
    read_entry || exit 1
    ! $public || pub_url="https://github.com/21StarkCom/homebrew-tap/releases/download/x-v9.9.9/x.zip"
    rewrite_entry "$OUT" && echo "$repo"' 2>&1)"
  changed="$(diff "${path}" "${work}/rewritten.rb" | grep -c '^>' || true)"
  check "${entry_rel} (release repo ${result##*"${NL}"})" eval '[ "$changed" = 3 ] && has "$result" 21StarkCom/'
done

begin "Decision 4: the gate's workflows are exactly the tap's pull_request workflows, unfiltered"
# Each .yml/.yaml in the directory that triggers on pull_request, and the filters
# on that trigger which could keep it from running on a bump PR.
pr_workflows() {
  ruby -ryaml -e '
    Dir[File.join(ARGV[0], "*.{yml,yaml}")].sort.each do |path|
      doc = YAML.safe_load(File.read(path)) || {}
      on = doc.key?("on") ? doc["on"] : doc[true] # YAML 1.1 reads a bare `on` as true
      triggers = case on
                 when String then { on => nil }
                 when Array then Hash[on.map { |t| [t, nil] }]
                 when Hash then on
                 else {}
                 end
      next unless triggers.key?("pull_request")
      cfg = triggers["pull_request"]
      cfg = {} unless cfg.is_a?(Hash)
      filters = cfg.keys & %w[paths paths-ignore branches branches-ignore]
      types = cfg["types"]
      filters << "types" if types && !(%w[opened synchronize] - Array(types)).empty?
      puts [File.basename(path), *filters].join(" ")
    end' "$1"
}
# 0 when the directory's pull_request workflows are GATE_WORKFLOWS, none filtered.
workflow_set_ok() {
  local listing file filters got="" filtered="" want
  listing="$(pr_workflows "$1")" || return 1
  while read -r file filters
  do
    [[ -n "${file}" ]] || continue
    got="${got} ${file}"
    [[ -z "${filters}" ]] || filtered="${filtered} ${file}(${filters})"
  done <<<"${listing}"
  want="$(cd "${root}" && bash -c '. scripts/bump.sh; echo "$GATE_WORKFLOWS"')"
  # shellcheck disable=SC2086 # split the word lists
  got="$(printf '%s\n' ${got} | sort | xargs)"
  # shellcheck disable=SC2086 # split the word lists
  want="$(printf '%s\n' ${want} | sort | xargs)"
  if [[ "${got}" != "${want}" ]]
  then
    echo "bump.sh GATE_WORKFLOWS is '${want}'; the pull_request workflows are '${got}'"
    return 1
  fi
  if [[ -n "${filtered}" ]]
  then
    echo "filtered pull_request triggers:${filtered}"
    return 1
  fi
}
check ".github/workflows matches GATE_WORKFLOWS" workflow_set_ok "${root}/.github/workflows"
planted="${work}/workflows"
rm -rf "${planted}"
cp -R "${root}/.github/workflows" "${planted}"
printf 'name: extra\non: [push, pull_request]\njobs: {}\n' >"${planted}/extra.yaml"
check "a planted extra pull_request workflow fails the test" eval '! workflow_set_ok "$planted" >/dev/null'
rm "${planted}/extra.yaml"
perl -0pi -e 's/\n  pull_request:\n/\n  pull_request:\n    paths: ["Formula\/**"]\n/' "${planted}/formulae.yml"
check "a planted paths: filter on formulae.yml fails the test" eval 'grep -q "paths:" "$planted/formulae.yml" && ! workflow_set_ok "$planted" >/dev/null'
cp "${root}/.github/workflows/formulae.yml" "${planted}/formulae.yml"
perl -0pi -e 's/\n  pull_request:\n/\n  pull_request:\n    types: [labeled]\n/' "${planted}/formulae.yml"
check "a pull_request types: filter that skips a bump PR fails the test" eval '! workflow_set_ok "$planted" >/dev/null'

printf '\n%s passed, %s failed\n' "${passed}" "${failed}"
[[ "${failed}" -eq 0 ]]
