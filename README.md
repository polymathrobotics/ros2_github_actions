# ros2_github_actions

Reusable github actions and cmake hooks. Currently just includes sanitizer jobs.

| Action | Purpose |
| --- | --- |
| [`asan`](#sanitizers) | Build and test a workspace under AddressSanitizer and UndefinedBehaviorSanitizer. |

# Sanitizers

```yaml
- uses: polymathrobotics/ros2_github_actions/asan@v1
```

Builds a ROS workspace with the sanitizer enabled, runs `colcon test` under the right
runtime environment, and reports results, without having to change the `CMakeLists.txt`
in the workspace under test.

| Action | Sanitizers | Compilers | Run Overhead |
| --- | --- | --- | --- |
| `asan` | address, undefined | GCC, clang | ~2x |

## Usage

```yaml
jobs:
  sanitize:
    runs-on: ubuntu-24.04
    container: ros:jazzy-ros-base
    steps:
      - uses: actions/checkout@v6
        with: {path: src/my_package}
      - uses: polymathrobotics/ros2_github_actions/asan@v1
```

Inputs:

| Input | Default | Purpose |
| --- | --- | --- |
| `workspace` | `.` | Colcon workspace root, containing `src/`. |
| `ros-setup` | `/opt/ros/${ROS_DISTRO}/setup.bash` | Sourced when present. |
| `exclude-packages` | `_msgs$` | Regex on CMake `PROJECT_NAME`; matches build uninstrumented. |
| `packages` | | Selection args for both build and test. |
| `build-args` / `test-args` | | Extra colcon args. |
| `compiler` | `g++` | Used to locate the sanitizer runtime library. |
| `skip-build` | `false` | Test an already-instrumented workspace. |

## How the flags are applied

`cmake/sanitizers.cmake` is passed as `-DCMAKE_PROJECT_INCLUDE`. That reaches every package
in the workspace without editing any of them, and applies flags as directory properties
so they land *after* the per-config flags.

Message packages are deliberately excluded so as to keep them usable and not break usage
with rclpy.

C and C++ are both instrumented, including a pure `project(foo C)` library with no C++ at
all. Compiles on x86 only.

Exclusion works per CMake project. A package that pulls in a nested project via
`add_subdirectory` passes its own compile options down, and the nested one inherits them
whatever its name.

## Outside GitHub Actions

The pieces are ordinary files. `scripts/sanitize.sh` takes `PRESET` and `WORKSPACE` from
the environment, and the tool is stdlib-only Python 3.10+:

```bash
python3 sanitizer_tool list
mapfile -t cmake_args < <(python3 sanitizer_tool cmake-args asan-ubsan)
colcon build --cmake-args "${cmake_args[@]}"

eval "$(python3 sanitizer_tool test-env asan-ubsan)"
colcon test --executor sequential
```

`cmake-args` prints one argument per line.

## Known rough edges

- **Leak detection is off.** ASan's leak checker is disabled, as CPython and the DDS stack
  leak enough at exit to bury codebase-specific findings.
- **Uninstrumented ROS.** Only your workspace is rebuilt with the flags; the apt ROS
  underneath is not.

## Tests

`test/run_preset.sh asan-ubsan` builds deliberately-buggy fixtures through the real
`CMAKE_PROJECT_INCLUDE` path and asserts each is caught, plus a package the exclude regex
matches that must stay uninstrumented. CI runs it on ubuntu 22.04, 24.04 and 26.04.
