// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <cstdio>
#include <thread>
#include <vector>

int main()
{
  std::vector<int> values(256, 1);
  int total = 0;
  std::thread worker([&values, &total]() {
    for (const int value : values) {
      total += value;
    }
  });
  worker.join();
  printf("%d\n", total);
  return 0;
}
