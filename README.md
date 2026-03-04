[![CI](https://github.com/allyourcodebase/tracy/actions/workflows/build.yml/badge.svg)](https://github.com/allyourcodebase/tracy/actions)

# Tracy Profiler

This is [Tracy](https://github.com/wolfpld/tracy), packaged for [Zig](https://ziglang.org/).

## Installation

Install Zig 0.15.2 and then run the following command:

```bash
zig build install-profiler
./zig-out/bin/tracy-profiler
```

You can also directly run the Tracy Profiler with the "run" step:

```bash
zig build run
```

### System Dependencies

When building for Windows or macOS, no system dependencies are required.

The graphical profiler has the following dependencies on Linux and FreeBSD:

- `libGL`, `libGLX`: runtime dependency
- `libEGL`: runtime dependency, not required when using `-Dlegacy`
- `libwayland-*` runtime dependencies to run a native wayland session
- `libX*` runtime dependencies to run a X11 session, only required when using `-Dlegacy`
- `libxkbcommon`: not required when using `-Dlegacy`
- `libdbus-1`: can be disabled with `-Dno-fileselector` or `-Dportal=false`
- `libgtk+-3.0`: only required when using `-Dportal=false`

#### System Integrations

Tracy has been ported with support for Zig's [System Integration Options](https://ziglang.org/download/0.12.0/release-notes.html#Ability-to-Declare-Optional-System-Library-Integration). By default, all system dependencies will be avoided except `libxkbcommon`.

### Cross Compilation

#### Windows

Cross compiling to windows works out of the box. It can even connect to a client that is running a different host (Linux).

```bash
zig build -Dtarget=x86_64-windows
zig build run -Dtarget=x86_64-windows -fwine # run the tracy profiler with Wine
```

#### Linux

This will produce a dynamically linked executable that will try to `dlopen` various runtime libraries. This is not guaranteed to work as all distros like NixOS.

```bash
zig build -Dtarget=x86_64-linux-gnu -Dlinkage=dynamic -Dno-fileselector -fno-sys=libxkbcommon -Dxkb-config-root=/usr/share/X11/xkb -Dx-locale-root=/usr/share/X11/locale
zig build -Dtarget=x86_64-linux-gnu -Dlinkage=dynamic -Dno-fileselector -Dlegacy
```

#### FreeBSD

```bash
zig build -Dtarget=x86_64-freebsd -Dno-fileselector -fno-sys=libxkbcommon -Dxkb-config-root=/usr/local/share/X11/xkb -Dx-locale-root=/usr/local/lib/X11/locale
zig build -Dtarget=x86_64-freebsd -Dno-fileselector -Dlegacy
```
