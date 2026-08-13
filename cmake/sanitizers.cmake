# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Injected into every package via -DCMAKE_PROJECT_INCLUDE, which CMake evaluates
# immediately after each project() call. Instruments a whole workspace without
# editing any package's CMakeLists.txt.
#
# Flags are applied as directory properties rather than CMAKE_CXX_FLAGS so they
# land after the per-config flags. A -DCMAKE_BUILD_TYPE=RelWithDebInfo would
# otherwise append -O2 and undo -O1 -fno-omit-frame-pointer.

if(NOT ROS2_SANITIZER)
  return()
endif()

# Excluded packages still build, just uninstrumented. Defaults to message packages
if(ROS2_SANITIZER_EXCLUDE AND PROJECT_NAME MATCHES "${ROS2_SANITIZER_EXCLUDE}")
  message(STATUS "ros2-sanitizers: skipping ${PROJECT_NAME}")
  return()
endif()

# Nothing here runs on the host, and no sanitizer runtime exists for most embedded
# toolchains. A repo mixing firmware with host code would otherwise fail to configure.
if(CMAKE_CROSSCOMPILING)
  message(STATUS "ros2-sanitizers: skipping ${PROJECT_NAME}, cross-compiling")
  return()
endif()

# Checked per enabled language rather than against CMAKE_CXX_COMPILER_ID alone, which is
# empty in a `project(foo C)` package and would reject every pure C library.
get_property(_ros2_sanitizer_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
set(_ros2_sanitizer_instrumentable OFF)

foreach(_ros2_sanitizer_lang IN ITEMS C CXX)
  if(_ros2_sanitizer_lang IN_LIST _ros2_sanitizer_languages)
    if(NOT CMAKE_${_ros2_sanitizer_lang}_COMPILER_ID MATCHES "GNU|Clang")
      message(FATAL_ERROR
        "ros2-sanitizers: unsupported ${_ros2_sanitizer_lang} compiler "
        "${CMAKE_${_ros2_sanitizer_lang}_COMPILER_ID}")
    endif()
    set(_ros2_sanitizer_instrumentable ON)
  endif()
endforeach()

# project(foo NONE), or a language-less interface package. Nothing to instrument.
if(NOT _ros2_sanitizer_instrumentable)
  return()
endif()

set(_ros2_sanitizer_common -O1 -g -fno-omit-frame-pointer)

if(ROS2_SANITIZER STREQUAL "asan-ubsan")
  # vptr is clang-only and false-positives on classes deriving from an uninstrumented
  # base, which is every rclcpp::Node subclass in an apt-installed ROS. Without
  # -fno-sanitize-recover UBSan reports a finding and the process still exits 0.
  set(_ros2_sanitizer_flags
    -fsanitize=address,undefined
    -fno-sanitize=vptr
    -fsanitize-address-use-after-scope
    -fno-sanitize-recover=all)
elseif(ROS2_SANITIZER STREQUAL "lsan")
  set(_ros2_sanitizer_flags -fsanitize=leak)
elseif(ROS2_SANITIZER STREQUAL "tsan")
  set(_ros2_sanitizer_flags -fsanitize=thread)
else()
  message(FATAL_ERROR "ros2-sanitizers: unknown preset '${ROS2_SANITIZER}'")
endif()

message(STATUS "ros2-sanitizers: instrumenting ${PROJECT_NAME} with ${ROS2_SANITIZER}")

add_compile_options(${_ros2_sanitizer_common} ${_ros2_sanitizer_flags})
add_link_options(${_ros2_sanitizer_flags})
