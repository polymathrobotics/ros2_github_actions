# SPDX-FileCopyrightText: 2026 Polymath Robotics, Inc.
# SPDX-License-Identifier: Apache-2.0

"""Run-stage half of the sanitizer presets: runtime options, suppressions, launcher.

Compile and link flags live in cmake/sanitizers.cmake, which CMake injects into every
package. This tool covers what CMake cannot: the environment the tests run under.

Stdlib only and ROS-agnostic, so it runs unmodified on a runner, inside a
`jobs.<id>.container:`, or inside a hand-rolled `docker run`.
"""

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SUPPRESSIONS_DIR = Path(__file__).resolve().parent / 'suppressions'
CMAKE_INCLUDE = REPO_ROOT / 'cmake' / 'sanitizers.cmake'

# rclpy dlopens generated message typesupport into an uninstrumented python3.
DEFAULT_EXCLUDE = '_msgs$'

PRESETS = {
    'asan-ubsan': {
        'summary': 'Address + undefined behavior. GCC and clang. Cheap enough to gate every PR.',
        'preload': 'libasan.so',
        'options': {
            # Leaks are the standalone `lsan` preset; ROS and CPython leak far too much at
            # exit to gate a PR on. ODR checks trip over pluginlib and component libraries.
            'ASAN_OPTIONS': ['detect_leaks=0', 'detect_odr_violation=0', 'print_stacktrace=1', 'halt_on_error=1'],
            'UBSAN_OPTIONS': ['print_stacktrace=1', 'halt_on_error=1'],
        },
    },
    'lsan': {
        'summary': 'Standalone leak detection. GCC and clang. Nightly.',
        'preload': 'liblsan.so',
        'options': {
            'LSAN_OPTIONS': ['print_suppressions=0', 'report_objects=1'],
        },
        'suppressions': {'LSAN_OPTIONS': 'lsan.supp'},
    },
    'tsan': {
        'summary': 'Data races. GCC and clang. Nightly only, 5-15x slowdown.',
        # No preload. TSan must own the address space from process start; preloading it
        # into an already-instrumented binary aborts with "unexpected memory mapping".
        # The cost is that TSan cannot cover tests driven by an uninstrumented python3.
        'preload': None,
        'options': {
            # Uninstrumented dependencies produce unavoidable reports; collect them all
            # rather than stopping at the first.
            'TSAN_OPTIONS': ['halt_on_error=0', 'history_size=7', 'second_deadlock_stack=1'],
        },
        'suppressions': {'TSAN_OPTIONS': 'tsan.supp'},
    },
}

# MemorySanitizer is deliberately absent: it is clang-only and requires every dependency
# down to libstdc++ to be instrumented, which no ROS apt stack provides.


def resolve_preload(lib: str, compiler: str) -> str | None:
    """Resolve a sanitizer runtime library to an absolute path.

    Covers the case of an uninstrumented python3 dlopening an instrumented library, which
    aborts unless the runtime is loaded first. The path is compiler-version specific, so
    it only resolves on the machine that runs the tests.

    @param lib       Runtime library name, e.g. `libasan.so`.
    @param compiler  Compiler driver to interrogate.
    @return          Absolute path, or None when the compiler does not ship the runtime.
    """
    try:
        result = subprocess.run([compiler, f'-print-file-name={lib}'], capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return None

    path = result.stdout.strip()
    # The driver echoes the bare name back when it cannot find the library.
    return path if path != lib and Path(path).exists() else None


def cmake_args(preset_name: str, exclude: str) -> list[str]:
    """Return the colcon --cmake-args that instrument every package in a workspace.

    @param preset_name  Key into PRESETS.
    @param exclude      Regex matched against PROJECT_NAME; matches build uninstrumented.
    @return             Argument list, ready to append to `colcon build --cmake-args`.
    """
    return [
        f'-DCMAKE_PROJECT_INCLUDE={CMAKE_INCLUDE}',
        f'-DROS2_SANITIZER={preset_name}',
        f'-DROS2_SANITIZER_EXCLUDE={exclude}',
    ]


def test_env(preset: dict, compiler: str) -> dict[str, str]:
    """Return the runtime option variables for running a sanitized test suite.

    @param preset    Entry from PRESETS.
    @param compiler  Compiler driver used to locate the runtime library.
    @return          Mapping of variable name to value.
    """
    env = {}
    suppressions = preset.get('suppressions', {})
    for var, options in preset['options'].items():
        values = list(options)
        supp = suppressions.get(var)
        if supp is not None:
            values.append(f'suppressions={SUPPRESSIONS_DIR / supp}')
        env[var] = ':'.join(values)

    preload_lib = preset.get('preload')
    preload = resolve_preload(preload_lib, compiler) if preload_lib is not None else None
    if preload is not None:
        # libstdc++ rides along because the runtime resolves the real __cxa_throw with
        # dlsym(RTLD_NEXT) while it initializes. python3 links no libstdc++, so without this
        # the symbol stays null and the first C++ exception thrown by anything python dlopens
        # (rclpy's pybind11 module) aborts inside the interceptor instead of reaching python.
        chain = [preload, resolve_preload('libstdc++.so.6', compiler), os.environ.get('LD_PRELOAD', '').strip()]
        env['LD_PRELOAD'] = ':'.join(entry for entry in chain if entry)

    return env


def main() -> int:
    parser = argparse.ArgumentParser(prog='sanitizer_tool', description=__doc__)
    subparsers = parser.add_subparsers(dest='command', required=True)

    subparsers.add_parser('list', help='list preset names and what they cover')

    cmake_parser = subparsers.add_parser('cmake-args', help='emit colcon --cmake-args for a preset')
    cmake_parser.add_argument('preset', choices=sorted(PRESETS))
    cmake_parser.add_argument(
        '--exclude', default=DEFAULT_EXCLUDE, help='regex of package names to leave uninstrumented'
    )

    env_parser = subparsers.add_parser('test-env', help='emit runtime option variables for a preset')
    env_parser.add_argument('preset', choices=sorted(PRESETS))
    env_parser.add_argument('--compiler', default=os.environ.get('CXX') or 'g++')
    env_parser.add_argument(
        '--format',
        choices=('shell', 'github-env'),
        default='shell',
        help='shell emits `export K=V` for eval; github-env emits bare K=V for $GITHUB_ENV',
    )

    args = parser.parse_args()

    if 'list' == args.command:
        for name, preset in sorted(PRESETS.items()):
            print(f'{name:<12} {preset["summary"]}')
        return 0

    if 'cmake-args' == args.command:
        # One argument per line. Shell-quoting them onto a single line breaks the caller:
        # a regex like `_msgs$` comes back quoted, and command substitution word-splits
        # without removing quotes, so CMake receives a literal quote character.
        # Read with `mapfile -t args < <(... cmake-args ...)`.
        print('\n'.join(cmake_args(args.preset, args.exclude)))
        return 0

    for var, value in test_env(PRESETS[args.preset], args.compiler).items():
        print(f'{var}={value}' if 'github-env' == args.format else f'export {var}={shlex.quote(value)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
