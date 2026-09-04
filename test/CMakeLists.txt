# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.16)
project(sanitizer_fixtures CXX)

find_package(Threads REQUIRED)

foreach(fixture heap_overflow signed_overflow no_defect)
  add_executable(${fixture} fixtures/${fixture}.cpp)
  target_link_libraries(${fixture} PRIVATE Threads::Threads)
endforeach()

# Loaded by python_throw, so the runtime reaches the
# process through LD_PRELOAD instead of the executable.
add_library(python_throw MODULE fixtures/python_throw.cpp)

# target_compile_options lands after the directory options this project injects, so a
# package's own -Werror outranks them.
add_executable(werror_regex fixtures/werror_regex.cpp)
target_compile_options(werror_regex PRIVATE -Wall -Wextra -Werror)

# test/excluded is configured as its own top-level project by run_preset.sh, not added
# here. Colcon configures each package independently, and a nested add_subdirectory would
# inherit this project's compile options and defeat the exclusion under test.
