// SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
// SPDX-License-Identifier: Apache-2.0
//
// Built with -Werror. GCC's uninitialized analysis does not survive the ASan
// instrumentation pass and false-positives inside libstdc++ <regex>.

#include <regex>
#include <string>

int main()
{
  const std::regex pattern(R"(^\s*(MSG:|=+)\s*(\S+)?\s*$)");
  const std::string line = "MSG: pkg/Type";
  std::smatch what;
  return std::regex_search(line, what, pattern) ? 0 : 1;
}
