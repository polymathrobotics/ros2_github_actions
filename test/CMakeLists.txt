# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.16)
project(sanitizer_fixtures CXX)

find_package(Threads REQUIRED)

foreach(fixture heap_overflow signed_overflow leak data_race no_defect)
  add_executable(${fixture} fixtures/${fixture}.cpp)
  target_link_libraries(${fixture} PRIVATE Threads::Threads)
endforeach()

# test/excluded is configured as its own top-level project by run_preset.sh, not added
# here. Colcon configures each package independently, and a nested add_subdirectory would
# inherit this project's compile options and defeat the exclusion under test.
