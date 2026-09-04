# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.16)

# A separate project() whose name the default exclude regex matches, configured on its own
# the way colcon configures each package. CMAKE_PROJECT_INCLUDE must decline this one.
#
# An overflow rather than a leak: detecting it requires instrumented loads, so it stays
# undetected exactly when exclusion worked. A leak would be caught regardless, because
# LeakSanitizer intercepts the allocator at runtime and never needed the compile flag.
project(fixtures_msgs CXX)

add_executable(excluded_overflow ../fixtures/heap_overflow.cpp)
