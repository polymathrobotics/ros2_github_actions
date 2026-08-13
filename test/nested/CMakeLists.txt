# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.16)

# Name matches the default exclude regex, so this project must stay uninstrumented.
project(fixtures_nested_msgs CXX)

# A nested project() whose own name does NOT match the regex, mirroring the project(gtest)
# that ament_cmake_gtest pulls in from gtest_vendor. If it were instrumented independently
# of its excluded parent, linking it in below would fail with undefined __asan_* symbols.
add_subdirectory(vendor)

add_executable(nested_no_defect ../fixtures/nested_no_defect.cpp)
target_link_libraries(nested_no_defect PRIVATE vendored)
