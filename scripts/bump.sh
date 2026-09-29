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
# The fleet's below-the-ticket-bar mark. idun gh pr-merge skips its ticket stamp
# only for a PR carrying it; unlabeled, the stamp falls back to whatever ticket
# the merging session is bound to. publish_pr syncs it to the PR's final title.
NO_TICKET_LABEL="no-ticket"
# A title that names a ticket, as idun gh pr-merge reads one (TICKET_PREFIX_RE
# in idun's src/gh/lib/draft_schema.ts, matched against the trimmed title).
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
VERSION_RE='^[[:space:]]*version[[:space:]]+"([^"]*)"'
NL=$'\n'

entry="" tag="" version="" ticket="" suffix="darwin_arm64.zip"
dry_run=false no_pr=false merge=false npos=0
tap_root="" rel="" repo="" pinned="" tmp="" restore_ref="" branch=""
a_id="" a_name="" sha="" pr="" pushed=""

usage() {
  local text
  IFS= read -r -d '' text <<'EOF' || true
Usage: scripts/bump.sh [flags] <entry> <tag> [flags]
       scripts/bump.sh [flags] -- <entry> <tag>

Point one entry of this tap at a published GitHub Release, then open a PR here.
The checkout this script sits in is the one it reads and edits: clone the tap
(depth 1 is enough) and run the script from that clone.

  <entry>             exactly one of Formula/<entry>.rb and Casks/<entry>.rb
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

A PR run needs this checkout clean (no tracked edits) and at origin's main. It
pushes bump/<entry>-<version> and opens a PR, or reuses the one open on that
branch: its body is refreshed, and its title only with --ticket. An existing
branch is rebuilt from main only while it is one commit ahead of main that
changes nothing but those three lines; any other branch is a human's edit, and
the run refuses it. Nothing is opened when main already pins the release, or
pins a newer X.Y.Z. The checkout ends the run back on the ref it started on.


The no-ticket label: every PR run syncs it to the PR's final title, read as idun
gh pr-merge reads one. A PR opened without --ticket gets it once open. A reused
PR keeps its live title without --ticket and gains or loses the label to match.
--ticket drops it BEFORE the retitle, and a failed drop stops the run with
nothing retitled. Any other failed add or drop is a warning, retried by the
next run on the branch.
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

# The entry's release repo, from its one asset url line, and the version it pins.
read_entry() {
  local line urls=0
  while IFS= read -r line || [[ -n "${line}" ]]
  do
    if [[ ${line} =~ ${URL_RE} ]]
    then
      urls=$((urls + 1))
      repo="${BASH_REMATCH[1]}"
    elif [[ -z "${pinned}" ]] && [[ ${line} =~ ${VERSION_RE} ]]
    then
      pinned="${BASH_REMATCH[1]}"
    fi
  done <"${tap_root}/${rel}"
  [[ "${urls}" -eq 1 ]] || die "${rel}: want one release asset url line, found ${urls}"
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

# I5: each of the three lines matches exactly once, or nothing is written. The
# rewrite goes to a copy, so the checkout is untouched until a mode writes it (I1).
rewrite_entry() {
  ENTRY="${rel}" REPO="${repo}" VER="${version}" ASSET="${a_id}" SHA="${sha}" perl -0777 -pe '
    my $repo = quotemeta $ENV{REPO};
    my %n = (
      "version"   => scalar(s{^([ \t]*version[ \t]+)"[^"]*"}{$1"$ENV{VER}"}mg),
      "asset url" => scalar(s{^([ \t]*url[ \t]+"https://api\.github\.com/repos/$repo/releases/assets/)[0-9]+"}{$1$ENV{ASSET}"}mg),
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
    $bad++ unless /^[-+][ \t]*(version[ \t]+"[^"]*"|url[ \t]+"https:\/\/api\.github\.com\/repos\/$r\/releases\/assets\/[0-9]+",?|sha256[ \t]+"[0-9a-f]{64}")[ \t]*$/;
    END { exit($bad || !$n ? 1 : 0) }' <<<"${patch}" || {
    say "    its commit changes more than the version, asset url and sha256 lines:"
    say "${patch}"
    return 1
  }
  printf '%s\n' "${tree}"
}

# Commit the rewrite on bump/<entry>-<version>, push it, and open or reuse its PR.
publish_pr() {
  local scope="chore" title body tip tip_tree="" tree url found pr_marked=false pr_title="" final_title want=false
  [[ -z "${ticket}" ]] || scope="chore(${ticket})"
  title="${scope}: bump ${entry} to ${tag}"
  body="Point \`${rel}\` at \`${a_name}\` (asset \`${a_id}\`, sha256 \`${sha}\`) from ${repo} ${tag}."
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
      # The mark goes BEFORE the ticket title (the operator rule), so the PR is
      # never ticket-titled and marked no-ticket at once.
      if [[ "${pr_marked}" = true ]]
      then
        gh pr edit "${pr}" -R "${TAP_REPO}" --remove-label "${NO_TICKET_LABEL}" >&2 ||
          die "could not remove ${NO_TICKET_LABEL} from PR #${pr}, so nothing was retitled; re-run to retry"
        pr_marked=false
      fi
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
  sync_no_ticket
}

# Sync publish_pr's PR to one rule: it carries the no-ticket mark exactly when
# its final title names no ticket. The add is never folded into gh pr create,
# which fails whole on a label the repo lacks; a pushed, open bump must not fail
# over its mark, so both steps only warn, and the next run on the branch retries.
sync_no_ticket() {
  ticket_titled "${final_title}" || want=true
  if [[ "${want}" = true ]] && [[ "${pr_marked}" != true ]]
  then
    if gh pr edit "${pr}" -R "${TAP_REPO}" --add-label "${NO_TICKET_LABEL}" >&2
    then
      pr_marked=true
    else
      say "bump.sh: warning: could not label PR #${pr} ${NO_TICKET_LABEL}; add it before idun gh pr-merge, or that merge stamps the session's bound ticket (the next run retries it)"
    fi
  elif [[ "${want}" != true ]] && [[ "${pr_marked}" = true ]]
  then
    if gh pr edit "${pr}" -R "${TAP_REPO}" --remove-label "${NO_TICKET_LABEL}" >&2
    then
      pr_marked=false
    else
      say "bump.sh: warning: could not remove ${NO_TICKET_LABEL} from PR #${pr}, whose title names a ticket; remove it before idun gh pr-merge, or that merge skips the ticket stamp (the next run retries it)"
    fi
  fi
  [[ "${pr_marked}" != true ]] ||
    say "==> PR #${pr} is labeled ${NO_TICKET_LABEL}: its title names no ticket. If a ticket covers this bump, drop the label, then retitle: gh pr edit ${pr} -R ${TAP_REPO} --remove-label ${NO_TICKET_LABEL}; gh pr edit ${pr} -R ${TAP_REPO} --title 'chore(STARK-<n>): bump ${entry} to ${tag}'"
}

# Whether title $1 names a ticket, as idun gh pr-merge reads it: TICKET_TITLE_RE
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
  local found=0 cand
  for cand in "Formula/${entry}.rb" "Casks/${entry}.rb"
  do
    if [[ -f "${tap_root}/${cand}" ]]
    then
      rel="${cand}"
      found=$((found + 1))
    fi
  done
  [[ "${found}" -ne 0 ]] || die "no tap entry ${entry}: neither Formula/${entry}.rb nor Casks/${entry}.rb exists in ${tap_root}"
  [[ "${found}" -eq 1 ]] || die "${entry} is ambiguous: both Formula/${entry}.rb and Casks/${entry}.rb exist"
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
  rewrite_entry "${tmp}/updated" || die "not rewriting ${rel}"
  if git diff --no-index --quiet -- "${tap_root}/${rel}" "${tmp}/updated"
  then
    say "==> ${rel} already pins ${repo} ${tag}; nothing to do"
    return 0
  fi
  say "==> ${rel}:"
  git --no-pager diff --no-index --no-ext-diff --no-color -- "${tap_root}/${rel}" "${tmp}/updated" >&2 || true
  if ${dry_run}
  then
    say "==> --dry-run: changed nothing"
    return 0
  fi
  if ${pr_run} && [[ ${pinned} =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]] && core_older "${version}" "${pinned}"
  then
    say "==> ${rel} pins ${pinned}, newer than ${version}: a PR run never moves an entry back (stage it with --no-pr)"
    return 0
  fi
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
