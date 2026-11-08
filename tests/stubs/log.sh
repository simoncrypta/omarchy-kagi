#!/bin/bash
# Shared argv log for the test stubs. One CALL/ARG/END record per invocation.

log_call() {
  local log=${KAGI_TEST_CALLS:-}
  [[ -n $log ]] || return 0
  {
    printf 'CALL\t%s\n' "$(basename "$0")"
    local arg
    for arg in "$@"; do
      printf 'ARG\t%s\n' "$arg"
    done
    printf 'END\n'
  } >> "$log"
}
