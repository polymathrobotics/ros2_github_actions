// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <cstdio>

// The sink is cleared so the allocation is genuinely unreachable at exit. Leaving the
// pointer live makes LSan classify it as still-reachable and report nothing.
static int * volatile sink;

int main()
{
  sink = new int[256];
  sink[0] = 1;
  printf("%d\n", sink[0]);
  sink = nullptr;
  return 0;
}
