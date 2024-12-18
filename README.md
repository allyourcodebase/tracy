[![CI](https://github.com/allyourcodebase/tracy/actions/workflows/build.yml/badge.svg)](https://github.com/allyourcodebase/tracy/actions)

# Tracy Profiler

This is [Tracy](https://github.com/wolfpld/tracy), packaged for [Zig](https://ziglang.org/).

## Installation

Install Zig 0.13.0 and then run the following command:

```bash
zig build install-profiler
./zig-out/bin/tracy-profiler
```

You can also directly run the Tracy Profiler with the "run" step:

```bash
zig build run
```

### System Dependencies

Most systems will already have the necessary dependencies installed by default.

#### Client

- `ws2_32` (windows)
- `dbghelp` (windows)
- `advapi32` (windows)
- `user32` (windows)
- `execinfo` (freeBSD)

#### Profiler & Other Tools

- `ws2_32` (windows)
- `dbghelp` (windows, tracy-update only)
- `ole32` (windows)
- `uuid` (windows)
- `shell32` (windows)
- `AppKit` (macOS)
- `UniformTypeIdentifiers` (macOS)
- `libGL` (linux)
- `libEGL` (linux, not required when using `-Dlegacy`)
- `libxkbcommon` (linux, not required when using `-Dlegacy`)
- `libdbus-1` (linux, can be disabled with `-Dno-fileselector` or `-Dportal=false`)
- `libgtk+-3.0` (linux, only required when using `-Dportal=false`)

#### System Integrations

Tracy has been ported with support for Zig's [System Integration Options](https://ziglang.org/download/0.12.0/release-notes.html#Ability-to-Declare-Optional-System-Library-Integration).

### Cross Compilation

#### Windows

Cross compiling to windows works out of the box. It can even connect to a client that is running a different host (Linux).

```bash
zig build -Dtarget=x86_64-windows
zig build run -Dtarget=x86_64-windows -fwine # run the tracy profiler with Wine
```

#### MacOS

Cross compiling to macos can successfully produce a binary. Whether it is functional has not been tested.

```bash
zig build -Dtarget=aarch64-macos -Dno-fileselector
file zig-out/bin/tracy-profiler
```

#### Linux

Cross compiling to Linux is currently not possible because of the dependency on `libGL` and `libEGL`.
