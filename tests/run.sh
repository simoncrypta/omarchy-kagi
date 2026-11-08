#!/bin/bash
set -euo pipefail

repo=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
kagi_bin=$(readlink -f "$repo/bin/kagi")

fail=0
kagi_rc=0
ok() { printf 'ok - %s\n' "$1"; }
not_ok() {
  printf 'not ok - %s\n' "$1"
  fail=1
}

expect_eq() {
  local name=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then
    ok "$name"
  else
    not_ok "$name"
    printf '# expected: %s\n# actual:   %s\n' "$expected" "$actual" >&2
  fi
}

expect_rc() {
  local name=$1 expected=$2
  if [[ $kagi_rc -eq $expected ]]; then
    ok "$name"
  else
    not_ok "$name"
    printf '# expected rc %s, got %s\n' "$expected" "$kagi_rc" >&2
    printf '# stdout:\n' >&2
    cat "$TMP/stdout" >&2 || true
    printf '# stderr:\n' >&2
    cat "$TMP/stderr" >&2 || true
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export KAGI_TEST_CALLS="$TMP/calls.log"
export PATH="$TMP/bin:${PATH}"
mkdir -p "$TMP/bin"
cp "$repo/tests/stubs/"* "$TMP/bin/"
chmod +x "$TMP/bin/"*
: > "$KAGI_TEST_CALLS"

# Abort if a stub did not win PATH, so no real menu or browser opens.
for cmd in omarchy-launch-browser omarchy-menu-input omarchy-notification-send wl-paste; do
  [[ $(command -v "$cmd") == "$TMP/bin/$cmd" ]] || {
    printf 'refusing to run: %s is %s\n' "$cmd" "$(command -v "$cmd")" >&2
    exit 1
  }
done

# shellcheck disable=SC1090,SC1091
source "$kagi_bin"

export KAGI_TEST_INPUT=''
export KAGI_TEST_INPUT_RC=0
export KAGI_TEST_CLIP=''
export KAGI_TEST_CLIP_RC=0

reset_calls() { : > "$KAGI_TEST_CALLS"; }

run_kagi() {
  set +e
  "$kagi_bin" "$@" >"$TMP/stdout" 2>"$TMP/stderr"
  kagi_rc=$?
  set -e
}

count_calls() {
  local cmd=$1
  awk -F '\t' -v cmd="$cmd" '$1 == "CALL" && $2 == cmd { n++ } END { print n + 0 }' "$KAGI_TEST_CALLS"
}

arg_n() {
  local cmd=$1 n=$2
  awk -F '\t' -v cmd="$cmd" -v n="$n" '
    $1 == "CALL" && $2 == cmd { grab = 1; i = 0; next }
    grab && $1 == "ARG" {
      i++
      if (i == n) { print $2; exit }
      next
    }
    grab && $1 == "END" { exit }
  ' "$KAGI_TEST_CALLS"
}

# --- URL building ---

expect_eq "search_url Monty Python" \
  "https://kagi.com/search?q=Monty%20Python" \
  "$(search_url "Monty Python")"

expect_eq "search_url !w Monty Python" \
  "https://kagi.com/search?q=%21w%20Monty%20Python" \
  "$(search_url "!w Monty Python")"

expect_eq "search_url how tall is everest? ends %3F" \
  "https://kagi.com/search?q=how%20tall%20is%20everest%3F" \
  "$(search_url "how tall is everest?")"

complex="café 日本 & # + ' \""
expect_eq "search_url space café 日本 & # + quote" \
  "https://kagi.com/search?q=caf%C3%A9%20%E6%97%A5%E6%9C%AC%20%26%20%23%20%2B%20%27%20%22" \
  "$(search_url "$complex")"

expect_eq "summarizer_url https://example.com/a?b=1&c=2#x" \
  "https://kagi.com/summarizer/index.html?url=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1%26c%3D2%23x" \
  "$(summarizer_url "https://example.com/a?b=1&c=2#x")"

# --- search ---

export KAGI_TEST_INPUT='Monty Python'
export KAGI_TEST_INPUT_RC=0
reset_calls
run_kagi search
expect_rc "search typed query exits 0" 0
expect_eq "search typed query exactly one browser call" "1" "$(count_calls omarchy-launch-browser)"
expect_eq "search typed query URL" \
  "https://kagi.com/search?q=Monty%20Python" \
  "$(arg_n omarchy-launch-browser 1)"
expect_eq "search prompt is Kagi" "Kagi" "$(arg_n omarchy-menu-input 1)"
expect_eq "search typed query no notification" "0" "$(count_calls omarchy-notification-send)"

export KAGI_TEST_INPUT_RC=1
export KAGI_TEST_INPUT='Monty Python'
reset_calls
run_kagi search
expect_rc "search escape exits 0" 0
expect_eq "search escape no browser" "0" "$(count_calls omarchy-launch-browser)"

export KAGI_TEST_INPUT=''
export KAGI_TEST_INPUT_RC=0
reset_calls
run_kagi search
expect_eq "search empty text rc 0 no browser" "0" "$(count_calls omarchy-launch-browser)"

export KAGI_TEST_INPUT='   '
export KAGI_TEST_INPUT_RC=0
reset_calls
run_kagi search
expect_eq "search blank text no browser" "0" "$(count_calls omarchy-launch-browser)"

# --- summarize ---

export KAGI_TEST_CLIP=$'https://example.com/a \n'
export KAGI_TEST_CLIP_RC=0
reset_calls
run_kagi summarize
expect_rc "summarize clipboard URL exits 0" 0
expect_eq "summarize clipboard URL opens summarizer" \
  "https://kagi.com/summarizer/index.html?url=https%3A%2F%2Fexample.com%2Fa" \
  "$(arg_n omarchy-launch-browser 1)"
expect_eq "summarize clipboard URL no notification" "0" "$(count_calls omarchy-notification-send)"
expect_eq "summarize calls wl-paste --no-newline" "--no-newline" "$(arg_n wl-paste 1)"
expect_eq "summarize calls wl-paste --type text" "text" "$(arg_n wl-paste 3)"

export KAGI_TEST_CLIP='not a url'
export KAGI_TEST_CLIP_RC=0
reset_calls
run_kagi summarize
expect_rc "summarize non-URL exits 0" 0
expect_eq "summarize non-URL one notification" "1" "$(count_calls omarchy-notification-send)"
expect_eq "summarize non-URL no browser" "0" "$(count_calls omarchy-launch-browser)"
expect_eq "summarize non-URL message" "Clipboard has no URL to summarize" "$(arg_n omarchy-notification-send 4)"

export KAGI_TEST_CLIP_RC=1
export KAGI_TEST_CLIP='https://example.com'
reset_calls
run_kagi summarize
expect_rc "summarize wl-paste rc 1 exits 0" 0
expect_eq "summarize wl-paste rc 1 one notification" "1" "$(count_calls omarchy-notification-send)"
expect_eq "summarize wl-paste rc 1 no browser" "0" "$(count_calls omarchy-launch-browser)"

export KAGI_TEST_CLIP='https://a b'
export KAGI_TEST_CLIP_RC=0
reset_calls
run_kagi summarize
expect_eq "summarize URL with space one notification" "1" "$(count_calls omarchy-notification-send)"
expect_eq "summarize URL with space no browser" "0" "$(count_calls omarchy-launch-browser)"

# --- main ---

run_kagi -h
expect_rc "kagi -h exits 0" 0
run_kagi --help
expect_rc "kagi --help exits 0" 0
run_kagi no-such
expect_rc "unknown command exits 2" 2
if [[ -s $TMP/stderr ]]; then
  ok "unknown command prints usage on stderr"
else
  not_ok "unknown command prints usage on stderr"
fi

# --- validate and shellcheck ---

if command -v omarchy-plugin-validate >/dev/null; then
  if omarchy-plugin-validate "$repo"; then
    ok "omarchy-plugin-validate"
  else
    not_ok "omarchy-plugin-validate"
  fi
else
  ok "omarchy-plugin-validate skipped (not installed)"
fi

if shellcheck "$repo/bin/kagi" "$repo/tests/run.sh" "$repo/tests/stubs/"*; then
  ok "shellcheck bin/kagi tests/run.sh stubs"
else
  not_ok "shellcheck bin/kagi tests/run.sh stubs"
fi

exit "$fail"
