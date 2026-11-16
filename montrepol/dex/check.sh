#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Check every .dx file here as a quine: Dex runs the file, and its output must
# equal the file, so each `>` line is an assertion. A failure prints a unified
# diff, in which "-> True" is an expected result Dex did not print.
# Needs dex/build.sh to have been run.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tc="$here/.toolchain"
cd "$tc/dex-lang"
status=0
for f in "$here"/*.dx; do
  out=$(mktemp)
  if ! "$tc/bin/dex" script "$f" > "$out"; then
    echo "FAIL $f: dex exited non-zero"
    status=1
  elif diff -u "$f" "$out"; then
    echo "OK   $f"
  else
    echo "FAIL $f: output differs from the file"
    status=1
  fi
  rm -f "$out"
done
exit $status
