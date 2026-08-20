#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Build deliberately-buggy fixtures through the real CMAKE_PROJECT_INCLUDE path and assert
# each is caught by exactly the preset that claims to find it. Catches a preset that has
# silently stopped detecting, which a build-only smoke test cannot.

set -euo pipefail

PRESET="${1:?usage: run_preset.sh <preset>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Fixture -> the one preset that must report it. `none` must stay clean under every preset.
# excluded_overflow is heap_overflow.cpp built in a package the exclude regex matches, so
# the pair proves opting a package out actually leaves it uninstrumented.
declare -A DETECTED_BY=(
  [heap_overflow]=asan-ubsan
  [signed_overflow]=asan-ubsan
  [leak]=lsan
  [data_race]=tsan
  [no_defect]=none
  [excluded_overflow]=none
  [c_heap_overflow]=asan-ubsan
  [nested_no_defect]=none
  [werror_regex]=none
  [python_throw]=none
)

# python_throw is the only fixture a preset can be excused from: it runs python3, which lsan
# reports interpreter leaks for and tsan cannot dlopen an instrumented library into at all
# ("cannot allocate memory in static TLS block"), the gap tsan preloading nothing admits to.
declare -A EXCUSED_PRESETS=(
  [python_throw]='lsan tsan'
)

mapfile -t CMAKE_ARGS < <(python3 "$ROOT/sanitizer_tool" cmake-args "$PRESET")

# Each source dir is configured on its own, the way colcon configures each package.
# RelWithDebInfo on purpose: its -O2 must not defeat the preset's -O1 -fno-omit-frame-pointer.
for source_dir in "$ROOT/test" "$ROOT/test/excluded" "$ROOT/test/pure_c" "$ROOT/test/nested"; do
  cmake -S "$source_dir" -B "$BUILD/$(basename "$source_dir")" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="$BUILD/bin" \
    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$BUILD/bin" \
    "${CMAKE_ARGS[@]}" >> "$BUILD/configure.log"
  cmake --build "$BUILD/$(basename "$source_dir")" --parallel > /dev/null
done
grep 'ros2-sanitizers:' "$BUILD/configure.log"

eval "$(python3 "$ROOT/sanitizer_tool" test-env "$PRESET")"

failures=0
ran=0
for fixture in "${!DETECTED_BY[@]}"; do
  if [[ " ${EXCUSED_PRESETS[$fixture]:-} " == *" $PRESET "* ]]; then
    echo "skip     $fixture (not applicable under $PRESET)"
    continue
  fi
  ran=$((ran + 1))

  expected=no
  if [[ "${DETECTED_BY[$fixture]}" == "$PRESET" ]]; then
    expected=yes
  fi

  command=("$BUILD/bin/$fixture")
  if [[ python_throw == "$fixture" ]]; then
    command=(python3 "$ROOT/test/fixtures/python_throw.py" "$BUILD/bin/lib$fixture.so")
  fi

  status=0
  output="$("${command[@]}" 2>&1)" || status=$?

  detected=no
  if [[ 0 -ne $status ]]; then
    detected=yes
  fi

  if [[ "$detected" == "$expected" ]]; then
    echo "ok       $fixture (detected=$detected)"
  else
    echo "NOT OK   $fixture (detected=$detected, expected=$expected, exit=$status)"
    echo "$output" | head -20
    failures=$((failures + 1))
  fi
done

echo "$failures failure(s) across $ran fixtures under $PRESET"
[[ 0 -eq $failures ]]
