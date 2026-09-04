// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include <stdlib.h>

int main(void)
{
  int * buffer = malloc(4 * sizeof(int));
  buffer[0] = 1;
  const int out_of_bounds = buffer[5];
  printf("%d\n", out_of_bounds);
  free(buffer);
  return 0;
}
