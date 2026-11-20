#!/usr/bin/env bash
# scripts/test-mirror.sh: tests for scripts/mirror.sh (docs/specs/getevinced-mirror.md,
# "Testing"). Each rig is a fake source tap holding a copy of mirror.sh and fixture
# entries only (no real entry, so a change to one never turns this gate red), a
# bare git remote that git reaches for GetEvinced/homebrew-tap (url.insteadOf),
# and a gh stub that keeps the GetEvinced releases in a JSON file and serves
# source assets from fixtures. Never the real taps. .github/workflows/bump.yml
# runs it.
#
# brew style's layout pass misreads a heredoc line that starts with `if`, so the
# stubs and the hook below use `case`, `&&` and `||` instead.
#
# brew style (formulae.yml) lints this with every optional shellcheck check. Off:
# single-quoted $names are jq's (SC2016); a case with no match has nothing to do
# (SC2249); fixture pipelines fail loudly downstream (SC2310, SC2312).
# shellcheck disable=SC2016,SC2249,SC2310,SC2312
set -uo pipefail

here="$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}" && pwd -P)"
root="${here%/*}"
for tool in git jq perl mktemp base64 zip unzip tar bsdtar
do
  command -v "${tool}" >/dev/null || {
    echo "test-mirror.sh: ${tool} is required" >&2
    exit 1
  }
done
sut_bash="$(command -v "${MIRROR_TEST_BASH:-bash}")"
REAL_GIT="$(command -v git)"
echo "mirror.sh runs under $("${sut_bash}" -c 'echo "bash $BASH_VERSION"')"

work="$(mktemp -d "${TMPDIR:-/tmp}/test-mirror.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export HOME="${work}/home" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=mirror-test GIT_AUTHOR_EMAIL=mirror-test@example.invalid
export GIT_COMMITTER_NAME=mirror-test GIT_COMMITTER_EMAIL=mirror-test@example.invalid
mkdir -p "${HOME}"

SRC_TOKEN="src-token-0123456789abcdef"
DST_TOKEN="dst-token-fedcba9876543210"
DST_BASIC="$(printf 'x-access-token:%s' "${DST_TOKEN}" | base64 | tr -d '\n')"
MARKER='# Mirrored from 21StarkCom/homebrew-tap by scripts/mirror.sh. Do not edit: the next run overwrites it.'
OLD_TIME="2020-01-01T00:00:00Z"
passed=0 failed=0 rigs=0 name="" code=0 out="" err="" R=""
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
  printf '     exit %s\n' "${code}"
  printf '%s\n' "${out}" | tail -n 15 | sed 's/^/     stdout: /'
  printf '%s\n' "${err}" | tail -n 15 | sed 's/^/     stderr: /'
}
check() { # check <what> <command...>
  local what="$1"
  shift
  if "$@"; then pass "${what}"; else flunk "${what}"; fi
}
is_code() { [[ ${code} == "$1" ]]; }
has() {
  case "$1" in *"$2"*) return 0 ;; esac
  return 1
}
out_has() { has "${out}" "$1"; }
out_line_starts() { has "${NL}${out}" "${NL}$1"; }
err_has() { has "${err}" "$1"; }
err_lacks() { ! has "${err}" "$1"; }
# Calls the gh stub logged that contain $1.
calls() { grep -cF -- "$1" "${R}/gh/log" 2>/dev/null || true; }
no_calls() { [[ "$(calls "$1")" == 0 ]]; }
count_is() { [[ "$(calls "$1")" == "$2" ]]; }

# --- the rig -----------------------------------------------------------------

formula_text() { # <name> <version> <asset id> <sha256>
  local cls
  cls="$(perl -e 'print ucfirst($ARGV[0])' "$1")"
  printf '%s\n' \
    '# frozen_string_literal: true' \
    '' \
    "# The $1 fixture." \
    "class ${cls} < Formula" \
    "  desc \"$1\"" \
    "  homepage \"https://github.com/21StarkCom/$1\"" \
    "  url \"https://api.github.com/repos/21StarkCom/$1/releases/assets/$3\"," \
    '      headers: ["Accept: application/octet-stream"]' \
    "  version \"$2\"" \
    "  sha256 \"$4\"" \
    ''
  case "$1" in
    libdemo)
      printf '%s\n' \
        '  depends_on "21starkcom/tap/demo"' \
        '' \
        '  def caveats' \
        '    <<~EOS' \
        '      Tap it first: brew tap 21StarkCom/tap' \
        '      Then: brew install 21StarkCom/tap/demo, or 21STARKCOM/tap/demo' \
        '      Its home is 21StarkCom/homebrew-tap; 21StarkCom/tapestry is not a tap.' \
        '    EOS' \
        '  end'
      ;;
    needssecret) printf '%s\n' '  depends_on "21StarkCom/tap/secret"' ;;
    bundled)
      printf '%s\n' \
        '  def install' \
        '    libexec.install Dir["*"]' \
        "    (bin/\"bundled\").write \"exec bun #{libexec}/bin/bundled.ts\"" \
        '  end' \
        '' \
        '  test do' \
        "    system \"bun\", \"#{opt_libexec}/lib/run.mts\"" \
        '    assert_path_exists libexec/"src/data.tsx"' \
        '  end'
      ;;
    *) printf '%s\n' '  def install' "    bin.install \"$1\"" '  end' ;;
  esac
  printf '%s\n' 'end'
}

cask_text() { # <version> <asset id> <sha256>
  printf '%s\n' \
    '# frozen_string_literal: true' \
    '' \
    'cask "democask" do' \
    "  version \"$1\"" \
    "  sha256 \"$3\"" \
    '' \
    "  url \"https://api.github.com/repos/21StarkCom/democask/releases/assets/$2\"," \
    '      using: DemocaskStrategy' \
    '  name "Democask"' \
    '  homepage "https://github.com/21StarkCom/democask"' \
    '' \
    '  caveats "Installing needs GitHub read access to 21StarkCom private repos."' \
    'end'
}

pkgcask_text() { # <version> <asset id> <sha256>: a cask whose asset is a .pkg, as idavoll's
  printf '%s\n' \
    '# frozen_string_literal: true' \
    '' \
    'cask "pkgcask" do' \
    "  version \"$1\"" \
    "  sha256 \"$3\"" \
    '' \
    "  url \"https://api.github.com/repos/21StarkCom/pkgcask/releases/assets/$2\"," \
    '      using: PkgcaskStrategy' \
    '  name "Pkgcask"' \
    '  homepage "https://github.com/21StarkCom/pkgcask"' \
    '' \
    '  pkg "pkgcask-#{version}.pkg"' \
    'end'
}

write_stub() {
  cat >"$1" <<'STUB'
#!/usr/bin/env bash
# gh, as far as mirror.sh uses it. GetEvinced releases live in $FAKE_GH/releases.json;
# source assets are $FAKE_GH/src/<owner>_<repo>/<id>.{bin,name}. Each call is
# logged with the side its GH_TOKEN belongs to, never the token itself.
set -u
S="$FAKE_GH"
T=GetEvinced/homebrew-tap
role=none
[[ ${GH_TOKEN:-} == "$FAKE_SRC_TOKEN" ]] && role=src
[[ ${GH_TOKEN:-} == "$FAKE_DST_TOKEN" ]] && role=dst
nl=$'\n'
line="$*"
printf '%s %s\n' "$role" "${line//$nl/ }" >>"$S/log"
nf() {
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
}
bad() {
  echo "gh stub: $*" >&2
  exit 91
}
need() { [[ $role == "$1" ]] || nf; }
rel() { jq "$@" "$S/releases.json"; }
save() { mv "$S/releases.new" "$S/releases.json"; }
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
next_id() {
  local n
  n="$(cat "$S/next_id")"
  echo $((n + 1)) >"$S/next_id"
  echo "$n"
}
hash_of() {
  command -v sha256sum >/dev/null 2>&1 || { shasum -a 256 "$1" | cut -c1-64; return; }
  sha256sum "$1" | cut -c1-64
}
emit() { # JSON on stdin, through --jq when given
  [[ -n $jqx ]] || { cat; return; }
  jq -r "$jqx"
}

case "$1 ${2:-}" in
  "release upload")
    need dst
    tag="$3" file="$4"
    [[ ${5:-} == -R && ${6:-} == "$T" ]] || bad "release upload $*"
    idx="$(rel --arg t "$tag" '[.[] | .tag_name == $t] | index(true) // empty')"
    [[ -n $idx ]] || { echo "release not found" >&2; exit 1; }
    id="$(next_id)"
    [[ -z ${FAKE_UPLOAD_FAIL:-} ]] || {
      rel --argjson i "$idx" --argjson id "$id" --arg n "${file##*/}" --arg u "$(stamp)" \
        '.[$i].assets += [{id: $id, name: $n, state: "starter", digest: null, updated_at: $u}]' >"$S/releases.new"
      save
      echo "upload failed" >&2
      exit 1
    }
    rel --argjson i "$idx" --argjson id "$id" --arg n "${file##*/}" --arg d "sha256:$(hash_of "$file")" --arg u "$(stamp)" \
      '.[$i].assets += [{id: $id, name: $n, state: "uploaded", digest: $d, updated_at: $u}]' >"$S/releases.new"
    save
    exit 0
    ;;
esac

[[ $1 == api ]] || bad "$*"
shift
method=GET accept="" jqx="" path="" draft="" tag="" title=""
while (($# > 0))
do
  case "$1" in
    -X) method="$2"; shift ;;
    -H) accept="$2"; shift ;;
    --jq) jqx="$2"; shift ;;
    --paginate) ;;
    -f | -F)
      case "$2" in
        tag_name=*) tag="${2#*=}" ;;
        name=*) title="${2#*=}" ;;
        draft=*) draft="${2#*=}" ;;
      esac
      shift
      ;;
    -*) bad "unknown flag $1" ;;
    *) path="$1" ;;
  esac
  shift
done

case "$method $path" in
  "GET repos/$T/releases?per_page=100")
    need dst
    # FAKE_HIDE_TAG leaves a release out of the listing, as a short page would.
    rel --arg h "${FAKE_HIDE_TAG:-}" 'map(select(.tag_name != $h))'
    ;;
  "GET repos/$T/releases/tags/"*)
    need dst
    rel -e --arg t "${path##*/tags/}" '[.[] | select(.tag_name == $t and (.draft | not))][0] // error' 2>/dev/null || nf
    ;;
  "GET repos/$T/releases/"[0-9]*)
    need dst
    rel --argjson id "${path##*/}" '.[] | select(.id == $id)' | emit
    ;;
  "POST repos/$T/releases")
    need dst
    rel -e --arg t "$tag" 'any(.[]; .tag_name == $t and (.draft | not))' >/dev/null &&
      { echo "gh: Validation Failed: already_exists (HTTP 422)" >&2; exit 1; }
    id="$(next_id)"
    rel --argjson id "$id" --arg t "$tag" --arg n "$title" --argjson d "$draft" \
      '. += [{id: $id, tag_name: $t, name: $n, draft: $d, assets: []}]' >"$S/releases.new"
    save
    jq -n --argjson id "$id" '{id: $id}' | emit
    ;;
  "PATCH repos/$T/releases/"[0-9]*)
    need dst
    rel --argjson id "${path##*/}" --argjson d "$draft" 'map(.draft = (.id == $id and $d or (.id != $id and .draft)))' >"$S/releases.new"
    save
    echo '{}'
    ;;
  "DELETE repos/$T/releases/assets/"[0-9]*)
    need dst
    rel --argjson id "${path##*/}" 'map(.assets |= map(select(.id != $id)))' >"$S/releases.new"
    save
    ;;
  "GET repos/"*"/releases/assets/"[0-9]*)
    need src
    repo="${path#repos/}"
    repo="${repo%/releases/assets/*}"
    f="$S/src/${repo//\//_}/${path##*/}"
    [[ -f $f.bin ]] || nf
    case "$accept" in
      "Accept: application/octet-stream") cat "$f.bin" ;;
      *) jq -n --arg n "$(cat "$f.name")" '{name: $n}' | emit ;;
    esac
    ;;
  *) bad "unhandled $method $path" ;;
esac
STUB
  chmod +x "$1"
}

# git, with one twist: while $FAKE_GH/race_pushes counts down, a push first lands
# another commit on the remote's main (an Evinced release pushing aac), so the
# mirror's push loses the race as it would on GitHub.
write_git_shim() {
  cat >"$1" <<'SHIM'
#!/usr/bin/env bash
n="$(cat "$FAKE_GH/race_pushes" 2>/dev/null || echo 0)"
case " $* " in
  *" push "*)
    [[ $n -gt 0 ]] && {
      echo $((n - 1)) >"$FAKE_GH/race_pushes"
      d="$(mktemp -d)"
      "$REAL_GIT" clone -q "$FAKE_REMOTE" "$d/c"
      echo "race $n" >"$d/c/Formula/other.rb"
      "$REAL_GIT" -C "$d/c" add -A
      "$REAL_GIT" -C "$d/c" commit -qm "their release $n"
      "$REAL_GIT" -C "$d/c" push -q origin HEAD:main
      rm -rf "$d"
    }
    ;;
esac
exec "$REAL_GIT" "$@"
SHIM
  chmod +x "$1"
}

# A fresh rig in $R: the source tap (demo, libdemo, democask, and kept, whose copy
# GetEvinced already holds), the GetEvinced remote with aac and evinced, and the
# gh stub with the fixture assets.
rig() {
  rigs=$((rigs + 1))
  R="${work}/rig${rigs}"
  mkdir -p "${R}/src/scripts" "${R}/src/Formula" "${R}/src/Casks" "${R}/bin" "${R}/gh/src" "${R}/tmp"
  # The rig's own exclusion list, so a change to the real one never turns this red.
  perl -pe 's/^EXCLUDED=.*/EXCLUDED="secret"/' "${root}/scripts/mirror.sh" >"${R}/src/scripts/mirror.sh"
  grep -qx 'EXCLUDED="secret"' "${R}/src/scripts/mirror.sh" || {
    echo "test-mirror.sh: cannot set EXCLUDED in the copy of mirror.sh" >&2
    exit 1
  }
  echo '[]' >"${R}/gh/releases.json"
  echo 9000 >"${R}/gh/next_id"
  : >"${R}/gh/log"
  write_stub "${R}/bin/gh"
  write_git_shim "${R}/bin/git"
  printf '[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n[url "file://%s"]\n\tinsteadOf = https://github.com/GetEvinced/homebrew-tap.git\n' \
    "${R}/target.git" >"${R}/gitconfig"
  export GIT_CONFIG_GLOBAL="${R}/gitconfig"
  source_asset demo 101 "demo 1.0.0"
  source_asset libdemo 201 "libdemo 1.0.0"
  source_asset democask 301 "democask 1.0.0"
  set_formula demo 1.0.0 101
  set_formula libdemo 1.0.0 201
  set_cask 1.0.0 301
  # kept's source asset is not served: the run must reuse GetEvinced's copy.
  formula_text kept 2.0.0 401 "$(printf '%064d' 4)" >"${R}/src/Formula/kept.rb"
  seed_release kept 2.0.0 "$(printf '%064d' 4)" 7001 kept.zip false uploaded
  git -C "${R}/src" init -q
  commit_src
  git init -q --bare "${R}/target.git"
  git init -q "${R}/seed"
  printf '# homebrew-tap\n\nHomebrew tap for Evinced internal CLIs.\n' >"${R}/seed/README.md"
  mkdir -p "${R}/seed/Formula"
  printf 'class Aac < Formula\n  desc "aac"\nend\n' >"${R}/seed/Formula/aac.rb"
  printf 'class Evinced < Formula\n  desc "evinced"\nend\n' >"${R}/seed/Formula/evinced.rb"
  push_seed seed
  AAC_SHA="$(tgt rev-parse main:Formula/aac.rb)"
  EVINCED_SHA="$(tgt rev-parse main:Formula/evinced.rb)"
}

source_asset() { # <repo> <id> <bytes> [asset name]: a zip of bin/<repo> holding <bytes>
  rm -rf "${R}/stage"
  stage_file "bin/$1" "$3"
  served_asset "$1" "$2" "${4:-$1-$2.zip}"
}
# Writes $R/stage/<path>, one line per argument after it: the tree of an archive.
stage_file() { # <path> <line>...
  local path="$1"
  shift
  mkdir -p "${R}/stage/${path%/*}"
  printf '%s\n' "$@" >"${R}/stage/${path}"
}
# Packs $R/stage into <archive>, as a .tar.gz, a .pkg or a .zip by <name>.
pack() { # <archive> <name>
  rm -f "$1"
  case "$2" in
    *.tar.gz) tar -czf "$1" -C "${R}/stage" . ;;
    *.pkg)
      # A flat .pkg, as pkgbuild makes one: a xar archive of a Payload (a gzip odc
      # cpio archive of the tree) and a PackageInfo, which is no archive.
      rm -rf "${R}/pkgroot"
      mkdir -p "${R}/pkgroot"
      bsdtar --format odc -czf "${R}/pkgroot/Payload" -C "${R}/stage" .
      printf '<pkg-info/>\n' >"${R}/pkgroot/PackageInfo"
      bsdtar --format xar -cf "$1" -C "${R}/pkgroot" .
      ;;
    *) (cd "${R}/stage" && zip -qry "$1" .) ;;
  esac
}
# Serves $R/stage, packed, as source asset <id> of 21StarkCom/<repo>.
served_asset() { # <repo> <id> <asset name>
  mkdir -p "${R}/gh/src/21StarkCom_$1"
  pack "${R}/gh/src/21StarkCom_$1/$2.bin" "$3"
  printf '%s' "$3" >"${R}/gh/src/21StarkCom_$1/$2.name"
}
asset_sha() { hash_of "${R}/gh/src/21StarkCom_$1/$2.bin"; }
set_formula() { # <name> <version> <asset id> [sha256]
  formula_text "$1" "$2" "$3" "${4:-$(asset_sha "$1" "$3")}" >"${R}/src/Formula/$1.rb"
}
set_cask() { # <version> <asset id> [sha256]
  cask_text "$1" "$2" "${3:-$(asset_sha democask "$2")}" >"${R}/src/Casks/democask.rb"
}
set_pkgcask() { # <version> <asset id>: Casks/i/pkgcask.rb, as idavoll's is in Casks/i/
  mkdir -p "${R}/src/Casks/i"
  pkgcask_text "$1" "$2" "$(asset_sha pkgcask "$2")" >"${R}/src/Casks/i/pkgcask.rb"
}
# Commits the source tap and makes that commit origin/main, as a fetched checkout has it.
commit_src() {
  git -C "${R}/src" add -A && git -C "${R}/src" commit -qm change &&
    git -C "${R}/src" update-ref refs/remotes/origin/main HEAD
}
push_seed() { # <message>: commits the seed checkout and pushes it to the remote's main
  git -C "${R}/seed" add -A && git -C "${R}/seed" commit -qm "$1" && git -C "${R}/seed" push -q "${R}/target.git" HEAD:main
}
seed_release() { # <entry> <version> <sha256> <asset id> <asset name> <draft> <state> [updated_at]
  local id
  id="$(cat "${R}/gh/next_id")"
  echo $((id + 1)) >"${R}/gh/next_id"
  jq --argjson rid "${id}" --arg t "$1-v$2" --arg d "sha256:$3" --argjson aid "$4" --arg n "$5" \
    --argjson draft "$6" --arg s "$7" --arg u "${8:-${OLD_TIME}}" \
    '. += [{id: $rid, tag_name: $t, name: $t, draft: $draft, assets: [{id: $aid, name: $n, state: $s, digest: (if $s == "uploaded" then $d else null end), updated_at: $u}]}]' \
    "${R}/gh/releases.json" >"${R}/gh/releases.new" && mv "${R}/gh/releases.new" "${R}/gh/releases.json"
}

run_check() { # [--check args]: mirror.sh --check, with no token
  out="$(cd "${R}" && env -u MIRROR_SOURCE_TOKEN -u MIRROR_TARGET_TOKEN TMPDIR="${R}/tmp" \
    "${sut_bash}" "${R}/src/scripts/mirror.sh" --check "$@" 2>"${R}/stderr")"
  code=$?
  err="$(cat "${R}/stderr")"
}

run_mirror() { # [mirror.sh args]; FAKE_* and MIRROR_KEEP_TMP from the caller's environment
  : >"${R}/gh/log"
  : >"${R}/output"
  out="$(cd "${R}" && env PATH="${R}/bin:${PATH}" REAL_GIT="${REAL_GIT}" FAKE_REMOTE="${R}/target.git" \
    FAKE_GH="${R}/gh" FAKE_SRC_TOKEN="${SRC_TOKEN}" FAKE_DST_TOKEN="${DST_TOKEN}" \
    MIRROR_SOURCE_TOKEN="${SRC_TOKEN}" MIRROR_TARGET_TOKEN="${DST_TOKEN}" \
    TMPDIR="${R}/tmp" GITHUB_OUTPUT="${R}/output" "${sut_bash}" "${R}/src/scripts/mirror.sh" "$@" 2>"${R}/stderr")"
  code=$?
  err="$(cat "${R}/stderr")"
}

# --- reads of the result -------------------------------------------------------

tgt() { "${REAL_GIT}" --git-dir="${R}/target.git" "$@"; }
tgt_file() { tgt show "${2:-main}:$1" 2>/dev/null; }
tgt_has() { tgt cat-file -e "${2:-main}:$1" 2>/dev/null; }
tgt_lacks() { ! tgt_has "$@"; }
head_of() { tgt rev-parse main 2>/dev/null; }
head_is() { [[ "$(head_of)" == "$1" ]]; }
aac_same() {
  [[ "$(tgt rev-parse "${1:-main}:Formula/aac.rb")" == "${AAC_SHA}" &&
  "$(tgt rev-parse "${1:-main}:Formula/evinced.rb")" == "${EVINCED_SHA}" ]]
}
readme_has() { tgt_file README.md | grep -qF -- "$1"; }
readme_lacks() { ! readme_has "$1"; }
copy_id() { # <path in target> → the asset id its url names
  tgt_file "$1" | sed -nE 's#.*repos/GetEvinced/homebrew-tap/releases/assets/([0-9]+)".*#\1#p'
}
rels() { jq "$@" "${R}/gh/releases.json"; }
release_exists() { rels -e --arg t "$1" 'any(.[]; .tag_name == $t)' >/dev/null; }
release_absent() { ! release_exists "$1"; }
releases_with_tag() { [[ "$(rels --arg t "$1" '[.[] | select(.tag_name == $t)] | length')" == "$2" ]]; }
no_drafts() { rels -e 'all(.[]; .draft == false)' >/dev/null; }
is_draft() { rels -e --arg t "$1" 'any(.[]; .tag_name == $t and .draft)' >/dev/null; }
asset_named() { # <tag> <name> <state>
  rels -e --arg t "$1" --arg n "$2" --arg s "$3" \
    'any(.[] | select(.tag_name == $t) | .assets[]; .name == $n and .state == $s)' >/dev/null
}
asset_exists() { rels -e --argjson id "$1" 'any(.[].assets[]; .id == $id)' >/dev/null; }
copy_points_at_uploaded() { # <path in target>
  local id
  id="$(copy_id "$1")"
  [[ -n ${id} ]] && rels -e --argjson id "${id}" 'any(.[].assets[]; .id == $id and .state == "uploaded")' >/dev/null
}
digest_is() { # <path in target> <tag> <sha256>
  local id
  id="$(copy_id "$1")"
  [[ -n ${id} ]] && rels -e --arg t "$2" --argjson id "${id}" --arg d "sha256:$3" \
    'any(.[] | select(.tag_name == $t) | .assets[]; .id == $id and .digest == $d)' >/dev/null
}
expected_copy() { # <source path> <asset id>: the copy, by sed, apart from mirror.sh's perl
  sed -n '1p' "$1"
  printf '\n%s\n\n' "${MARKER}"
  sed '1,2d' "$1" | sed -E \
    -e "s#(url[[:space:]]+\"https://api\\.github\\.com/repos/)21StarkCom/[A-Za-z0-9_.-]+(/releases/assets/)[0-9]+\"#\\1GetEvinced/homebrew-tap\\2$2\"#" \
    -e 's#21StarkCom/tap([^A-Za-z0-9_]|$)#GetEvinced/tap\1#g' \
    -e 's#21STARKCOM/tap([^A-Za-z0-9_]|$)#GetEvinced/tap\1#g' \
    -e 's#21starkcom/tap([^A-Za-z0-9_]|$)#getevinced/tap\1#g' \
    -e 's#read access to 21StarkCom private repos#read access to GetEvinced private repos#g'
}
copy_is_expected() { # <rel path> <asset id>
  diff <(expected_copy "${R}/src/$1" "$2") <(tgt_file "$1") >"${R}/copy.diff"
}
copy_has() { tgt_file "$1" | grep -qF -- "$2"; }
no_21stark_tap() { ! tgt grep -qiE '21starkcom/tap([^a-z0-9_]|$)' main -- Formula Casks; }
line3_is_marker() { [[ "$(tgt_file Formula/demo.rb | sed -n 3p)" == "${MARKER}" ]]; }
changed_files_are() { [[ "$(tgt diff --name-only main~1 main | tr '\n' ' ')" == "$1" ]]; }
output_line() { grep -qxF -- "$1" "${R}/output"; }
output_lists() { # <key> <entry>
  local v
  v="$(grep -E "^$1=" "${R}/output")"
  v=" ${v#*=} "
  has "${v}" " $2 "
}
log_lacks() { ! grep -qE -- "$1" "${R}/gh/log"; }
writes_use_target_token() { ! grep -E 'api -X (POST|PATCH|DELETE)|release upload' "${R}/gh/log" | grep -qv '^dst '; }
no_secret_in() { ! grep -rqF -e "${SRC_TOKEN}" -e "${DST_TOKEN}" -e "${DST_BASIC}" "$@"; }
no_secret_in_output() { ! printf '%s\n%s\n' "${out}" "${err}" | grep -qF -e "${SRC_TOKEN}" -e "${DST_TOKEN}" -e "${DST_BASIC}"; }

# --- tests -------------------------------------------------------------------

begin "first run into an empty tap"
rig
run_mirror
check "exit 0" is_code 0
check "uploads demo, libdemo and democask" count_is "dst release upload" 3
check "downloads with the source token only" count_is "src api -H Accept: application/octet-stream" 3
check "reuses kept's copy: no read of its source" no_calls "21StarkCom/kept"
for e in demo libdemo kept; do check "Formula/${e}.rb pushed" tgt_has "Formula/${e}.rb"; done
check "Casks/democask.rb pushed" tgt_has Casks/democask.rb
check "kept points at the copy GetEvinced held" bash -c '[[ $1 == 7001 ]]' _ "$(copy_id Formula/kept.rb)"
check "demo's url names a GetEvinced asset with demo's bytes" digest_is Formula/demo.rb demo-v1.0.0 "$(asset_sha demo 101)"
check "releases are published" no_drafts
check "aac and evinced unchanged" aac_same
check "README keeps the Evinced text" readme_has "Homebrew tap for Evinced internal CLIs."
check "README block lists demo" readme_has '| `demo` | formula | 1.0.0 | [21StarkCom/demo](https://github.com/21StarkCom/demo) |'
check "README block lists the cask" readme_has '| `democask` | cask | 1.0.0 |'
check "GITHUB_OUTPUT lists demo" output_lists formulae demo
check "GITHUB_OUTPUT lists democask" output_lists casks democask
check "GITHUB_OUTPUT pushed=true" output_line pushed=true

begin "the copy rules, checked by sed"
check "libdemo.rb: dependency, caveats, any case" copy_is_expected Formula/libdemo.rb "$(copy_id Formula/libdemo.rb)"
check "democask.rb: GetEvinced private repos" copy_is_expected Casks/democask.rb "$(copy_id Casks/democask.rb)"
check "demo.rb" copy_is_expected Formula/demo.rb "$(copy_id Formula/demo.rb)"
check "libdemo depends on getevinced/tap/demo" copy_has Formula/libdemo.rb 'depends_on "getevinced/tap/demo"'
check "an uppercase 21STARKCOM/tap is renamed too" copy_has Formula/libdemo.rb 'or GetEvinced/tap/demo'
check "21StarkCom/homebrew-tap and 21StarkCom/tapestry stay" copy_has Formula/libdemo.rb 'Its home is 21StarkCom/homebrew-tap; 21StarkCom/tapestry is not a tap.'
check "no copy names 21starkcom/tap" no_21stark_tap
check "line 3 is the marker" line3_is_marker

begin "a second run with no change"
before="$(head_of)"
run_mirror
check "exit 0" is_code 0
check "no upload" no_calls "release upload"
check "no download" no_calls "application/octet-stream"
check "no new commit" head_is "${before}"
check "says no change" out_has "no change"
check "GITHUB_OUTPUT lists nothing" output_line "formulae="

begin "a version bump of one entry"
source_asset demo 102 "demo 1.1.0"
set_formula demo 1.1.0 102
commit_src
run_mirror
check "exit 0" is_code 0
check "one upload" count_is "dst release upload" 1
check "demo points at the 1.1.0 copy" digest_is Formula/demo.rb demo-v1.1.0 "$(asset_sha demo 102)"
check "the commit changes demo and the README only" changed_files_are "Formula/demo.rb README.md "
check "GITHUB_OUTPUT lists demo alone" output_line "formulae=demo"
check "GITHUB_OUTPUT lists no cask" output_line "casks="
check "the 1.0.0 release stays" release_exists demo-v1.0.0

begin "the same version with new bytes"
# A rebuild under the same version keeps its asset name.
source_asset democask 302 "democask 1.0.0, rebuilt" democask-301.zip
set_cask 1.0.0 302
commit_src
run_mirror
new_sha="$(asset_sha democask 302)"
check "exit 0" is_code 0
check "uploads under a sha-prefixed name" asset_named democask-v1.0.0 "${new_sha:0:12}-democask-301.zip" uploaded
check "the old asset stays" asset_named democask-v1.0.0 democask-301.zip uploaded
check "democask points at the new bytes" digest_is Casks/democask.rb democask-v1.0.0 "${new_sha}"

begin "an entry removed here"
git -C "${R}/src" rm -q Formula/libdemo.rb && commit_src
run_mirror
check "exit 0" is_code 0
check "its marked file goes" tgt_lacks Formula/libdemo.rb
check "its release stays" release_exists libdemo-v1.0.0
check "the README block drops it" readme_lacks '`libdemo`'
check "aac and evinced unchanged" aac_same

begin "the README block whose END line has no newline"
"${REAL_GIT}" clone -q "${R}/target.git" "${R}/edit"
perl -0777 -pi -e 's/\n\z//' "${R}/edit/README.md"
"${REAL_GIT}" -C "${R}/edit" commit -qam "edited on the web" && "${REAL_GIT}" -C "${R}/edit" push -q origin HEAD:main
source_asset demo 103 "demo 1.2.0"
set_formula demo 1.2.0 103
commit_src
run_mirror
check "exit 0" is_code 0
check "the block shows demo 1.2.0" readme_has '| `demo` | formula | 1.2.0 |'
check "the block appears once" bash -c '[[ $(grep -c "BEGIN 21stark-mirror" <<<"$1") == 1 ]]' _ "$(tgt_file README.md)"

begin "excluded entries"
rig
printf '# frozen_string_literal: true\n\nclass Secret < Formula\nend\n' >"${R}/src/Formula/secret.rb"
commit_src
mkdir -p "${R}/seed/Formula"
printf '# frozen_string_literal: true\n\n%s\n\nclass Secret < Formula\nend\n' "${MARKER}" >"${R}/seed/Formula/secret.rb"
push_seed "a copy made before the exclusion"
run_mirror
check "exit 0" is_code 0
check "says secret is excluded" out_has "secret: excluded; not copied"
check "no gh call names secret" log_lacks "secret"
check "deletes the marked secret copy" tgt_lacks Formula/secret.rb
check "says why" out_has "secret: is excluded from the mirror; deleting Formula/secret.rb"
run_mirror --only secret
check "--only an excluded entry exits 2" is_code 2

begin "an entry that names an excluded one"
rig
source_asset needssecret 501 "needssecret 1.0.0"
set_formula needssecret 1.0.0 501
commit_src
run_mirror
check "exit 1" is_code 1
check "says it names an excluded entry" err_has "it names 21StarkCom/tap/secret, which the mirror excludes"
check "no copy of it" tgt_lacks Formula/needssecret.rb
check "nothing of it is read or uploaded" log_lacks needssecret
check "the others are pushed" tgt_has Formula/demo.rb

begin "an entry moved from Formula/ to Casks/"
rig
mkdir -p "${R}/seed/Formula"
printf '# frozen_string_literal: true\n\n%s\n\nclass Democask < Formula\nend\n' "${MARKER}" >"${R}/seed/Formula/democask.rb"
push_seed "democask was a formula"
run_mirror
check "exit 0" is_code 0
check "deletes the old formula copy" tgt_lacks Formula/democask.rb
check "writes the cask copy" tgt_has Casks/democask.rb
check "says it moved" out_has "democask: moved to Casks/democask.rb"

begin "a formula and a cask with one name"
rig
set_formula democask 1.0.0 301
commit_src
run_mirror
check "exit 1" is_code 1
check "says it is both" err_has "is both Formula/democask.rb and Casks/democask.rb"
check "copies neither" bash -c '! git --git-dir="$1" cat-file -e main:Formula/democask.rb 2>/dev/null && ! git --git-dir="$1" cat-file -e main:Casks/democask.rb 2>/dev/null' _ "${R}/target.git"
check "the others are pushed" tgt_has Formula/demo.rb

# A rig whose tap also holds pkgcask: a cask in Casks/i/ whose asset is a .pkg.
pkg_rig() {
  rig
  rm -rf "${R}/stage"
  stage_file Applications/Pkgcask.app/Contents/Resources/app.asar "console.log('pkgcask 1.0.0')"
  stage_file usr/local/bin/pkgcask "pkgcask 1.0.0"
  served_asset pkgcask 701 pkgcask-1.0.0.pkg
  set_pkgcask 1.0.0 701
  commit_src
}

begin "a cask in Casks/i/ whose asset is a .pkg"
pkg_rig
run_mirror
check "exit 0" is_code 0
check "uploads the .pkg under its own name" asset_named pkgcask-v1.0.0 pkgcask-1.0.0.pkg uploaded
check "writes Casks/i/pkgcask.rb" tgt_has Casks/i/pkgcask.rb
check "writes no Casks/pkgcask.rb" tgt_lacks Casks/pkgcask.rb
check "the copy rules hold" copy_is_expected Casks/i/pkgcask.rb "$(copy_id Casks/i/pkgcask.rb)"
check "its url names a GetEvinced asset with its bytes" digest_is Casks/i/pkgcask.rb pkgcask-v1.0.0 "$(asset_sha pkgcask 701)"
check "README block lists it" readme_has '| `pkgcask` | cask | 1.0.0 | [21StarkCom/pkgcask](https://github.com/21StarkCom/pkgcask) |'
check "GITHUB_OUTPUT lists it" output_lists casks pkgcask
cp "${R}/gh/src/21StarkCom_pkgcask/701.bin" "${R}/pkgcask-1.0.0.pkg"
run_check pkgcask "${R}/pkgcask-1.0.0.pkg"
check "--check finds it in Casks/i/: exit 0" is_code 0
check "--check says it passes" out_has "pkgcask: pkgcask-1.0.0.pkg passes the source check"
run_mirror
check "a second run: exit 0" is_code 0
check "a second run: no change" out_has "no change"
git -C "${R}/src" rm -q Casks/i/pkgcask.rb && commit_src
run_mirror
check "removed here: exit 0" is_code 0
check "removed here: its marked copy goes" tgt_lacks Casks/i/pkgcask.rb
check "removed here: says why" out_has "pkgcask: left 21StarkCom/homebrew-tap; deleting Casks/i/pkgcask.rb"

begin "a cask moved into Casks/i/"
pkg_rig
mkdir -p "${R}/seed/Casks"
printf '# frozen_string_literal: true\n\n%s\n\ncask "pkgcask" do\nend\n' "${MARKER}" >"${R}/seed/Casks/pkgcask.rb"
push_seed "pkgcask was in Casks/"
run_mirror
check "exit 0" is_code 0
check "deletes the old copy" tgt_lacks Casks/pkgcask.rb
check "writes the new one" tgt_has Casks/i/pkgcask.rb
check "says it moved" out_has "pkgcask: moved to Casks/i/pkgcask.rb"

begin "a cask in Casks/ and in Casks/i/ with one name"
rig
mkdir -p "${R}/src/Casks/i"
cp "${R}/src/Casks/democask.rb" "${R}/src/Casks/i/democask.rb"
commit_src
run_mirror
check "exit 1" is_code 1
check "says it is both" err_has "is both Casks/democask.rb and Casks/i/democask.rb"
check "copies neither" bash -c '! git --git-dir="$1" cat-file -e main:Casks/democask.rb 2>/dev/null && ! git --git-dir="$1" cat-file -e main:Casks/i/democask.rb 2>/dev/null' _ "${R}/target.git"
cp "${R}/gh/src/21StarkCom_democask/301.bin" "${R}/democask.zip"
run_check democask "${R}/democask.zip"
check "--check refuses it too: exit 1" is_code 1
check "--check says it is both" err_has "democask: is both Casks/democask.rb and Casks/i/democask.rb"

begin "the source checkout must be what main holds"
rig
echo "# stray" >>"${R}/src/Formula/demo.rb"
run_mirror
check "uncommitted Formula/ change: exit 2" is_code 2
check "says so" err_has "uncommitted changes"
git -C "${R}/src" checkout -q -- Formula/demo.rb
git -C "${R}/src" commit -q --allow-empty -m "ahead of origin/main"
run_mirror
check "HEAD not origin/main: exit 2" is_code 2
check "says to fetch" err_has "is not origin/main"
run_mirror --branch mirror-proof
check "a scratch branch may copy any commit: exit 0" is_code 0
run_mirror --dry-run
check "a dry run may plan from any commit: exit 0" is_code 0

begin "a SHA-256 mismatch on download"
rig
set_formula demo 1.0.0 101 "$(printf '%064d' 7)"
commit_src
run_mirror
check "exit 1" is_code 1
check "says the asset does not match" err_has "does not match the pinned sha256"
check "demo is not written" tgt_lacks Formula/demo.rb
check "the other entries are pushed" tgt_has Casks/democask.rb
check "names the failed entry" err_has "FAILED demo"

begin "an incomplete upload a dead run left"
rig
seed_release demo 1.0.0 "$(asset_sha demo 101)" 6001 demo-101.zip true starter
run_mirror
check "exit 0" is_code 0
check "deletes the incomplete upload" count_is "dst api -X DELETE repos/GetEvinced/homebrew-tap/releases/assets/6001" 1
check "uploads into the existing draft, not a new release" releases_with_tag demo-v1.0.0 1
check "publishes the draft" no_drafts
check "demo points at an uploaded asset" copy_points_at_uploaded Formula/demo.rb

begin "an upload another run has in progress"
rig
seed_release demo 1.0.0 "$(asset_sha demo 101)" 6201 demo-101.zip true open "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
run_mirror
check "exit 1" is_code 1
check "says an upload is in progress" err_has "an upload to demo-v1.0.0 is in progress (asset 6201)"
check "deletes nothing" no_calls "api -X DELETE"
check "the upload stays" asset_exists 6201
check "the others are pushed" tgt_has Formula/libdemo.rb

begin "a draft a dead run left with the right asset"
rig
seed_release demo 1.0.0 "$(asset_sha demo 101)" 6101 demo-101.zip true uploaded
run_mirror
check "exit 0" is_code 0
check "reuses it: no upload for demo" log_lacks "release upload demo-v1.0.0"
check "publishes it" count_is "dst api -X PATCH" 3
check "demo points at it" bash -c '[[ $1 == 6101 ]]' _ "$(copy_id Formula/demo.rb)"
check "no drafts left" no_drafts

begin "a release the listing misses"
rig
seed_release demo 1.0.0 "$(asset_sha demo 101)" 6301 demo-101.zip false uploaded
FAKE_HIDE_TAG=demo-v1.0.0 run_mirror
check "exit 0" is_code 0
check "asks for the tag" count_is "dst api repos/GetEvinced/homebrew-tap/releases/tags/demo-v1.0.0" 1
check "reuses its asset" bash -c '[[ $1 == 6301 ]]' _ "$(copy_id Formula/demo.rb)"
check "makes no second release" releases_with_tag demo-v1.0.0 1

begin "two releases with one tag"
rig
seed_release demo 1.0.0 "$(printf '%064d' 1)" 6401 demo-a.zip false uploaded
seed_release demo 1.0.0 "$(printf '%064d' 2)" 6402 demo-b.zip true starter
run_mirror
check "exit 1" is_code 1
check "says to delete the extra one" err_has "more than one release tagged demo-v1.0.0"
check "uploads nothing for demo" log_lacks "release upload demo-v"

begin "an upload that fails"
rig
FAKE_UPLOAD_FAIL=1 run_mirror --only demo
check "exit 1" is_code 1
check "demo is not written" tgt_lacks Formula/demo.rb
check "leaves a draft" is_draft demo-v1.0.0
run_mirror --only demo
check "a run at once sees the upload as in progress: exit 1" is_code 1
check "and deletes nothing" no_calls "api -X DELETE"
# The failed upload counts as in progress until an hour has passed.
jq '(.[].assets[] | select(.state != "uploaded") | .updated_at) = "2020-01-01T00:00:00Z"' "${R}/gh/releases.json" >"${R}/gh/r.new" &&
  mv "${R}/gh/r.new" "${R}/gh/releases.json"
run_mirror --only demo
check "an hour on, the next run heals it: exit 0" is_code 0
check "it deletes the incomplete upload" count_is "dst api -X DELETE" 1
check "demo points at an uploaded asset" copy_points_at_uploaded Formula/demo.rb
check "no drafts left" no_drafts

begin "an unmarked GetEvinced file with an entry's name"
rig
printf 'class Demo < Formula\n  desc "Evinced own demo"\nend\n' >"${R}/seed/Formula/demo.rb"
push_seed "their demo"
theirs="$(tgt rev-parse main:Formula/demo.rb)"
run_mirror
check "exit 1" is_code 1
check "says it is not ours" err_has "without the mirror marker"
check "the file stays" bash -c '[[ $1 == "$2" ]]' _ "$(tgt rev-parse main:Formula/demo.rb)" "${theirs}"
check "no upload for demo" log_lacks "release upload demo-v"
check "the other entries are pushed" tgt_has Formula/libdemo.rb

begin "a push that loses a race"
rig
echo 1 >"${R}/gh/race_pushes"
run_mirror
check "exit 0" is_code 0
check "says it clones again" err_has "cloning again (try 2 of 3)"
check "pushes on the second try" tgt_has Formula/demo.rb
check "keeps the commit that won the race" tgt_has Formula/other.rb
check "uploads once" count_is "dst release upload" 3
check "GITHUB_OUTPUT lists demo" output_lists formulae demo

begin "a push the remote refuses"
rig
cat >"${R}/target.git/hooks/pre-receive" <<'HOOK'
#!/bin/sh
echo "GH013: Repository rule violations found" >&2
exit 1
HOOK
chmod +x "${R}/target.git/hooks/pre-receive"
run_mirror
check "exit 1" is_code 1
check "says the push was refused" err_has "refused the push"
check "does not retry" err_lacks "cloning again"

begin "--branch with a branch that does not exist yet"
rig
main_before="$(head_of)"
run_mirror --branch mirror-proof
check "exit 0" is_code 0
check "makes the branch" tgt_has Formula/demo.rb mirror-proof
check "from main" tgt merge-base --is-ancestor "${main_before}" mirror-proof
check "main is unchanged" head_is "${main_before}"
check "aac and evinced unchanged on the branch" aac_same mirror-proof

begin "--only"
rig
run_mirror
source_asset demo 102 "demo 1.1.0"
set_formula demo 1.1.0 102
source_asset democask 303 "democask 1.2.0"
set_cask 1.2.0 303
git -C "${R}/src" rm -q Formula/libdemo.rb
commit_src
run_mirror --only demo
check "exit 0" is_code 0
check "copies demo" digest_is Formula/demo.rb demo-v1.1.0 "$(asset_sha demo 102)"
check "leaves democask alone" log_lacks democask
check "deletes no file" tgt_has Formula/libdemo.rb
run_mirror --only nosuch
check "an unknown entry exits 2" is_code 2

begin "no secret in the work directory, the gh arguments or the output"
rig
MIRROR_KEEP_TMP=1 run_mirror
check "exit 0" is_code 0
check "the kept work directory holds no token or basic credential" no_secret_in "${R}/tmp"
check "the gh log holds none" no_secret_in "${R}/gh/log"
check "the output holds none" no_secret_in_output
check "every write uses the target token" writes_use_target_token

begin "--dry-run"
rig
before="$(head_of)"
out="$(cd "${R}" && env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
  PATH="${R}/bin:${PATH}" REAL_GIT="${REAL_GIT}" FAKE_REMOTE="${R}/target.git" FAKE_GH="${R}/gh" \
  FAKE_SRC_TOKEN="${SRC_TOKEN}" FAKE_DST_TOKEN="${DST_TOKEN}" MIRROR_TARGET_TOKEN="${DST_TOKEN}" \
  TMPDIR="${R}/tmp" "${sut_bash}" "${R}/src/scripts/mirror.sh" --dry-run 2>"${R}/stderr")"
code=$?
err="$(cat "${R}/stderr")"
check "exit 0, with no git identity and no source token" is_code 0
for e in demo libdemo democask kept; do check "names ${e}" out_line_starts "${e} "; done
check "shows the files a copy would write" out_has "Formula/demo.rb"
check "no upload, create, publish or delete" log_lacks 'api -X|release upload'
check "no download" no_calls "application/octet-stream"
check "no push" head_is "${before}"
check "says what it would push" out_has "dry run: would commit and push"

# A minified line: 320 bytes, over mirror.sh's MINIFIED_LINE_BYTES.
MIN="$(printf 'let a=1;%.0s' {1..40})"
# bundled names bin/bundled.ts, lib/run.mts and src/data.tsx under libexec.
bundled_rig() {
  rig
  formula_text bundled 1.0.0 601 "$(printf '%064d' 6)" >"${R}/src/Formula/bundled.rb"
  rm -rf "${R}/stage"
}

begin "the source check: what passes"
bundled_rig
stage_file bin/bundled.ts "// @bun" "${MIN}${MIN}"
stage_file lib/run.mts "${MIN}"
stage_file src/data.tsx "${MIN}"
stage_file types/index.d.ts "export declare const a: number;"
stage_file dist/bin.js "console.log(1)"
stage_file node_modules/lodash/index.js.map '{"version":3,"sourcesContent":["x"]}'
stage_file node_modules/@types/node/index.ts "export {}"
stage_file node_modules/@21starkcom/kit/dist/index.js "export const a = 1"
stage_file node_modules/@21starkcom/kit/dist/index.d.ts "export declare const a: number;"
stage_file node_modules/@21starkcom/kit/node_modules/dep/index.js.map '{"sourcesContent":[]}'
stage_file node_modules/.pnpm/@atlas+cli@1.0.0/node_modules/@atlas/cli/package.json '{"name":"@atlas/cli"}'
ln -s .pnpm/@atlas+cli@1.0.0/node_modules/@atlas/cli "${R}/stage/node_modules/cli-link"
pack "${R}/clean.zip" clean.zip
run_check bundled "${R}/clean.zip"
check "exit 0" is_code 0
check "says it passes" out_has "bundled: clean.zip passes the source check"
check "says nothing on stderr" bash -c '[[ -z $1 ]]' _ "${err}"
pack "${R}/clean.tar.gz" clean.tar.gz
run_check bundled "${R}/clean.tar.gz"
check "a .tar.gz: exit 0" is_code 0

# Runs the check of bundled on an archive of a minified bin/bundled.ts and one
# more file, <path> with each <line>; asserts that it refuses that file.
refuses() { # <what> <archive name> <path> <reason> <line>...
  local what="$1" archive="$2" path="$3" why="$4"
  shift 4
  rm -rf "${R}/stage"
  stage_file bin/bundled.ts "${MIN}"
  stage_file "${path}" "$@"
  pack "${R}/${archive}" "${archive}"
  run_check bundled "${R}/${archive}"
  check "${what}: exit 1" is_code 1
  check "${what}: names the file and why" err_has "bundled: ${path}: ${why}"
  check "${what}: says it is not copied" err_has "bundled: ${archive} holds source in 1 file(s), so it is not copied"
}

begin "the source check: what it refuses"
bundled_rig
refuses "a .ts outside node_modules" case.zip src/app.ts "TypeScript source" "const a: number = 1"
refuses "a .tsx" case.zip src/view.tsx "TypeScript source" "export const v = <div />"
refuses "a .mts" case.zip src/mod.mts "TypeScript source" "export {}"
refuses "a .cts" case.zip src/mod.cts "TypeScript source" "export {}"
refuses "a minified .ts the entry does not name" case.zip bin/other.ts "TypeScript source" "${MIN}"
refuses "a named .ts that is not minified" case.zip lib/run.mts "TypeScript source, not minified" \
  "const a = 1" "const b = 2" "export { a, b }"
refuses "a .map outside node_modules" case.zip dist/bin.js.map "a source map" '{"version":3}'
refuses "a .map in a first-party package" case.zip node_modules/@21starkcom/kit/dist/index.js.map \
  "a source map in a first-party package" '{"version":3}'
refuses "a .map in a first-party package of the bun layout" case.zip \
  node_modules/.bun/@sleipnir+core@1.0.0/node_modules/@sleipnir/core/dist/index.js.map \
  "a source map in a first-party package" '{"version":3}'
refuses "a .ts in a first-party package" case.zip node_modules/@atlas/cli/src/index.ts \
  "TypeScript source in a first-party package" "export {}"
refuses "sourcesContent in a first-party package" case.zip \
  node_modules/.pnpm/@atlas+cli@1.0.0/node_modules/@atlas/cli/dist/bin.js \
  "holds sourcesContent in a first-party package" 'const m = {"sourcesContent": ["x"]}'
refuses "an inline source map outside node_modules" case.zip dist/bin.js "an inline source map" \
  "console.log(1)" "//# sourceMappingURL=data:application/json;base64,e30="
refuses "an inline source map in a first-party package" case.zip node_modules/@21starkcom/kit/index.mjs \
  "an inline source map in a first-party package" "//# sourceMappingURL=data:application/json;base64,e30="
refuses "a .ts in a .tar.gz" case.tar.gz src/app.ts "TypeScript source" "const a: number = 1"
refuses "an upper-case .TS" case.zip src/App.TS "TypeScript source" "const a: number = 1"
refuses "an upper-case .MAP" case.zip dist/bin.js.MAP "a source map" '{"version":3}'
refuses "sourcesContent in a .json outside node_modules" case.zip dist/sources.json \
  "holds sourcesContent" '{"version":3,"sourcesContent":["x"]}'
refuses "a .map in an @idun package" case.zip node_modules/@idun/core/dist/index.js.map \
  "a source map in a first-party package" '{"version":3}'

begin "the source check of a .pkg"
bundled_rig
# An Electron app: app.asar is read as one file, and third-party packages are not read.
app=Applications/Demo.app/Contents/Resources
stage_file "${app}/app.asar" "const a = require('./src/main.ts');"
stage_file "${app}/app.asar.unpacked/node_modules/lodash/index.js.map" '{"sourcesContent":["x"]}'
stage_file usr/local/bin/demo "demo 1.0.0"
pack "${R}/clean.pkg" clean.pkg
run_check bundled "${R}/clean.pkg"
check "a clean .pkg: exit 0" is_code 0
check "a clean .pkg: says it passes" out_has "bundled: clean.pkg passes the source check"
stage_file "${app}/src/main.ts" "const a: number = 1"
stage_file "${app}/app.asar.unpacked/node_modules/@21starkcom/kit/index.js.map" '{"version":3}'
pack "${R}/case.pkg" case.pkg
run_check bundled "${R}/case.pkg"
check "source in the Payload: exit 1" is_code 1
check "names the .ts by its path in the Payload" err_has "bundled: Payload/${app}/src/main.ts: TypeScript source"
check "names the first-party .map" \
  err_has "bundled: Payload/${app}/app.asar.unpacked/node_modules/@21starkcom/kit/index.js.map: a source map in a first-party package"
check "says it is not copied" err_has "bundled: case.pkg holds source in 2 file(s), so it is not copied"
rm -rf "${R}/pkgroot"
mkdir -p "${R}/pkgroot"
printf '<pkg-info/>\n' >"${R}/pkgroot/PackageInfo"
# An empty member: libarchive reads it as an empty archive, but it is no Payload.
: >"${R}/pkgroot/Empty"
bsdtar --format xar -cf "${R}/nopayload.pkg" -C "${R}/pkgroot" .
run_check bundled "${R}/nopayload.pkg"
check "a .pkg with no Payload: exit 1" is_code 1
check "a .pkg with no Payload: says so" err_has "cannot unpack nopayload.pkg: it holds no Payload to check"
# A Payload bsdtar cannot read (as Apple's pbzx), beside a Scripts archive it can.
rm -f "${R}/pkgroot/Empty"
mkdir -p "${R}/pkgscripts"
printf '#!/bin/sh\n' >"${R}/pkgscripts/postinstall"
bsdtar --format odc -czf "${R}/pkgroot/Scripts" -C "${R}/pkgscripts" .
printf 'pbzx not a cpio archive\n' >"${R}/pkgroot/Payload"
bsdtar --format xar -cf "${R}/pbzx.pkg" -C "${R}/pkgroot" .
run_check bundled "${R}/pbzx.pkg"
check "an unreadable Payload: exit 1" is_code 1
check "an unreadable Payload: names it" err_has "cannot unpack pbzx.pkg: its Payload is no archive that bsdtar reads"
printf 'not a xar archive\n' >"${R}/broken.pkg"
run_check bundled "${R}/broken.pkg"
check "a broken .pkg: exit 1" is_code 1
check "a broken .pkg: says it cannot unpack it" err_has "cannot unpack broken.pkg"

begin "the source check: archives it cannot read, and usage"
bundled_rig
printf 'not an archive\n' >"${R}/asset.dmg"
run_check bundled "${R}/asset.dmg"
check "an archive of another kind: exit 1" is_code 1
check "says what it reads" err_has "reads only a .zip, a .tar.gz or a .pkg, not asset.dmg"
printf 'not a zip\n' >"${R}/broken.zip"
run_check bundled "${R}/broken.zip"
check "a broken zip: exit 1" is_code 1
check "says it cannot unpack it" err_has "cannot unpack broken.zip"
run_check nosuch "${R}/broken.zip"
check "an unknown entry: exit 2" is_code 2
run_check bundled "${R}/missing.zip"
check "a missing archive: exit 2" is_code 2
run_check bundled
check "no archive: exit 2" is_code 2
run_mirror --dry-run --check bundled "${R}/broken.zip"
check "with another option: exit 2" is_code 2

begin "an asset that holds source is not copied"
rig
rm -rf "${R}/stage"
stage_file bin/demo "demo 1.0.0"
stage_file src/main.ts "const a: number = 1"
served_asset demo 101 demo-101.zip
set_formula demo 1.0.0 101
commit_src
run_mirror
check "exit 1" is_code 1
check "says demo holds source" err_has "demo: demo-101.zip holds source in 1 file(s), so it is not copied"
check "names the file" err_has "demo: src/main.ts: TypeScript source"
check "makes no demo release" release_absent demo-v1.0.0
check "uploads nothing for demo" log_lacks "release upload demo-v"
check "demo is not written" tgt_lacks Formula/demo.rb
check "the others are pushed" tgt_has Formula/libdemo.rb
check "names the failed entry" err_has "FAILED demo"

# The rename files (spec D13).
renames_are() { # <file> <compact JSON, keys sorted>
  [[ "$(tgt_file "$1" | jq -cS .)" == "$2" ]]
}
set_renames() { # <file> <JSON>: the source tap's rename file
  printf '%s\n' "$2" >"${R}/src/$1"
}
last_message_has_line() { tgt log -1 --format=%B main | grep -qxF -- "$1"; }
target_file_is() { [[ "$(tgt_file "$1")" == "$2" ]]; }

begin "rename files: copied, dropped and kept pairs"
rig
set_renames formula_renames.json '{"olddemo": "demo", "oldsecret": "secret", "gone": "nosuch", "wrongkind": "democask"}'
set_renames cask_renames.json '{"oldcask": "democask", "notacask": "demo"}'
commit_src
mkdir -p "${R}/seed"
printf '{\n  "oldsecret": "secret",\n  "evold": "evnew"\n}\n' >"${R}/seed/formula_renames.json"
push_seed "GetEvinced pairs of its own"
run_mirror
check "exit 0" is_code 0
check "formula pairs: copied, excluded dropped, GetEvinced kept" \
  renames_are formula_renames.json '{"evold":"evnew","olddemo":"demo"}'
check "cask pairs: copied, a formula's dropped" renames_are cask_renames.json '{"oldcask":"democask"}'
check "says why a pair is not copied" out_has "formula_renames.json: oldsecret -> secret is not copied: secret is no formula of the mirror"
check "the commit names the rename files" last_message_has_line "- formula_renames.json"
check "aac and evinced unchanged" aac_same
before="$(head_of)"
run_mirror
check "a second run: exit 0" is_code 0
check "a second run: no new commit" head_is "${before}"

begin "rename files: a pair dropped later is removed"
set_renames formula_renames.json '{"oldsecret": "secret"}'
rm -f "${R}/src/cask_renames.json"
commit_src
run_mirror
check "exit 0" is_code 0
check "olddemo stays: the source file lacks its old name" \
  renames_are formula_renames.json '{"evold":"evnew","olddemo":"demo"}'
check "a removed source file leaves its GetEvinced pairs" renames_are cask_renames.json '{"oldcask":"democask"}'
set_renames formula_renames.json '{"olddemo": "secret"}'
commit_src
run_mirror
check "a dropped pair removes its old name" renames_are formula_renames.json '{"evold":"evnew"}'

begin "rename files: no pair kept, no file"
rig
run_mirror
check "no source file: exit 0" is_code 0
check "no formula_renames.json" tgt_lacks formula_renames.json
check "no cask_renames.json" tgt_lacks cask_renames.json
set_renames formula_renames.json '{"oldsecret": "secret"}'
set_renames cask_renames.json '{}'
commit_src
run_mirror
check "only dropped pairs: exit 0" is_code 0
check "still no formula_renames.json" tgt_lacks formula_renames.json
check "still no cask_renames.json" tgt_lacks cask_renames.json

begin "rename files: a failed entry keeps its pair"
rig
run_mirror
check "the first copy: exit 0" is_code 0
set_formula demo 1.1.0 101 "$(printf '%064d' 9)"
set_renames formula_renames.json '{"olddemo": "demo"}'
commit_src
run_mirror
check "exit 1" is_code 1
check "demo failed" err_has "FAILED demo"
check "its pair is copied" renames_are formula_renames.json '{"olddemo":"demo"}'

begin "rename files: a failed entry with no copy holds its pair"
rig
set_formula demo 1.0.0 101 "$(printf '%064d' 9)"
set_renames formula_renames.json '{"olddemo": "demo", "oldlib": "libdemo"}'
commit_src
mkdir -p "${R}/seed"
printf '{"olddemo": "evdemo"}\n' >"${R}/seed/formula_renames.json"
push_seed "a GetEvinced pair of the held old name"
run_mirror
check "exit 1" is_code 1
check "demo failed" err_has "FAILED demo"
check "says the pair waits" out_has "formula_renames.json: the pair to demo waits"
check "the held old name stays as it was; the other pair is copied" \
  renames_are formula_renames.json '{"olddemo":"evdemo","oldlib":"libdemo"}'

begin "rename files: --only changes none"
rig
set_renames formula_renames.json '{"olddemo": "demo"}'
commit_src
run_mirror --only demo
check "exit 0" is_code 0
check "no formula_renames.json" tgt_lacks formula_renames.json

begin "rename files: one that is not a map of names"
rig
set_renames formula_renames.json '["olddemo", "demo"]'
set_renames cask_renames.json '{"oldcask": "democask"}'
commit_src
mkdir -p "${R}/seed"
printf '{"evold": "evnew"}\n' >"${R}/seed/formula_renames.json"
push_seed "a GetEvinced pair"
run_mirror
check "exit 1" is_code 1
check "names the bad file" err_has "FAILED formula_renames.json: it is not a JSON object of entry names to entry names"
check "the GetEvinced file stays" renames_are formula_renames.json '{"evold":"evnew"}'
check "the other rename file is copied" renames_are cask_renames.json '{"oldcask":"democask"}'
check "the entries are pushed" tgt_has Formula/demo.rb
rig
set_renames formula_renames.json '{"olddemo": "demo"}'
commit_src
mkdir -p "${R}/seed"
printf 'not json\n' >"${R}/seed/formula_renames.json"
push_seed "a broken GetEvinced file"
run_mirror
check "a broken GetEvinced file: exit 1" is_code 1
check "says it is left" err_has "has a formula_renames.json that is not a JSON object of entry names; it is left as it is"
check "it stays as it was" target_file_is formula_renames.json "not json"
check "the entries are pushed" tgt_has Formula/demo.rb
rig
set_renames formula_renames.json '{"olddemo": "demo"}'
commit_src
mkdir -p "${R}/seed"
printf '{"a": "b"}\n{"c": "d"}\n' >"${R}/seed/formula_renames.json"
push_seed "a GetEvinced file of two objects"
run_mirror
check "a file of two objects: exit 1" is_code 1
check "a file of two objects: says it is left" err_has "has a formula_renames.json that is not a JSON object of entry names"
check "a file of two objects: the entries are pushed" tgt_has Formula/demo.rb
rig
set_renames formula_renames.json '{"olddemo\n": "demo"}'
commit_src
run_mirror
check "a name that ends in a newline: exit 1" is_code 1
check "a name that ends in a newline: names the bad file" err_has "FAILED formula_renames.json"

begin "rename files: an uncommitted change"
rig
set_renames formula_renames.json '{"olddemo": "demo"}'
run_mirror
check "exit 2" is_code 2
check "says what is uncommitted" err_has "formula_renames.json"

begin "usage"
run_mirror --bogus
check "an unknown flag exits 2" is_code 2
out="$(env -u MIRROR_TARGET_TOKEN "${sut_bash}" "${R}/src/scripts/mirror.sh" 2>&1)"
code=$?
check "a missing MIRROR_TARGET_TOKEN exits 2" is_code 2
out="$("${sut_bash}" "${R}/src/scripts/mirror.sh" --help)"
code=$?
check "--help exits 0" is_code 0
check "--help names the environment" out_has "MIRROR_TARGET_TOKEN"
check "--help names the source check" out_has "--check <entry> <archive>"
check "--help names the rename files" out_has "formula_renames.json and cask_renames.json"

printf '\n%s passed, %s failed\n' "${passed}" "${failed}"
((failed == 0))
