#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Build and test a colcon workspace under one sanitizer preset. Shared by the per-sanitizer
# actions so the build and test logic exists once.

set -euo pipefail

PRESET="${PRESET:?PRESET is required}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$REPO_ROOT/sanitizer_tool"

WORKSPACE="${WORKSPACE:-.}"
ROS_SETUP="${ROS_SETUP:-/opt/ros/${ROS_DISTRO:-}/setup.bash}"
EXCLUDE_PACKAGES="${EXCLUDE_PACKAGES:-_msgs$}"
PACKAGES="${PACKAGES:-}"
BUILD_ARGS="${BUILD_ARGS:-}"
TEST_ARGS="${TEST_ARGS:-}"
COMPILER="${COMPILER:-g++}"
SKIP_BUILD="${SKIP_BUILD:-false}"

cd "$WORKSPACE"

if [[ -f "$ROS_SETUP" ]]; then
  # shellcheck disable=SC1090
  source "$ROS_SETUP"
fi

if [[ 'true' != "$SKIP_BUILD" ]]; then
  mapfile -t CMAKE_ARGS < <(python3 "$TOOL" cmake-args "$PRESET" --exclude "$EXCLUDE_PACKAGES")
  echo "::group::colcon build ($PRESET)"
  # shellcheck disable=SC2086
  colcon build \
    --event-handlers console_cohesion+ summary+ \
    $PACKAGES \
    $BUILD_ARGS \
    --cmake-args "${CMAKE_ARGS[@]}"
  echo '::endgroup::'
fi

eval "$(python3 "$TOOL" test-env "$PRESET" --compiler "$COMPILER")"

echo "::group::colcon test ($PRESET)"
# shellcheck disable=SC2086
colcon test \
  --executor sequential \
  --event-handlers console_cohesion+ \
  $PACKAGES \
  $TEST_ARGS
echo '::endgroup::'

colcon test-result --verbose
