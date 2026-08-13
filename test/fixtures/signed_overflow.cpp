// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <cstdio>

__attribute__((noinline)) int add(int a, int b)
{
  return a + b;
}

int main()
{
  printf("%d\n", add(2147483647, 1));
  return 0;
}
