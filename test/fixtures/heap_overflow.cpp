// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <cstdio>

int main()
{
  int * buffer = new int[4];
  buffer[0] = 1;
  const int out_of_bounds = buffer[5];
  printf("%d\n", out_of_bounds);
  delete[] buffer;
  return 0;
}
