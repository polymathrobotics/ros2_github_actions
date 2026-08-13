// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0

#include <cstdio>
#include <thread>

static int shared_counter = 0;

static void increment()
{
  for (int i = 0; i < 10000; ++i) {
    ++shared_counter;
  }
}

int main()
{
  std::thread first(increment);
  std::thread second(increment);
  first.join();
  second.join();
  printf("%d\n", shared_counter);
  return 0;
}
