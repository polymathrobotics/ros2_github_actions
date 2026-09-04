# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.16)
project(vendored_lib CXX)

add_library(vendored STATIC ../../fixtures/vendored.cpp)
