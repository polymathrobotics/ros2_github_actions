// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <stdexcept>

/// Throw and catch inside a library that python3 dlopens, the way rclpy's pybind11 module
/// does. Nothing here is a defect: the exception is what the runtime has to survive.
extern "C" int throw_and_catch()
{
  try {
    throw std::runtime_error("thrown from a dlopened library");
  } catch (const std::runtime_error &) {
    return 0;
  }
}
