# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.16)

# A C-only project, the shape a firmware or transport library uses. CMAKE_CXX_COMPILER_ID
# is empty here, so this catches a guard that only inspects the C++ compiler.
project(fixtures_c C)

add_executable(c_heap_overflow ../fixtures/c_heap_overflow.c)
