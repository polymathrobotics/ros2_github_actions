#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0

"""Drive the python_throw fixture from an uninstrumented python3, as the launch tests do."""

import ctypes
import sys

if __name__ == '__main__':
    sys.exit(ctypes.CDLL(sys.argv[1]).throw_and_catch())
