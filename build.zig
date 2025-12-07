const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pie = b.option(bool, "pie", "Produce a Position Independent Executable");

    // Client Options
    const enable = b.option(bool, "enable", "Enable profiling") orelse true;
    const on_demand = b.option(bool, "on-demand", "On-demand profiling") orelse false;
    const callstack = b.option(usize, "callstack", "Enforce callstack collection for tracy regions") orelse 0;
    const no_callstack = b.option(bool, "no-callstack", "Disable all callstack related functionality") orelse false;
    const no_callstack_inlines = b.option(bool, "no-callstack-inlines", "Disables the inline functions in callstacks") orelse false;
    const only_localhost = b.option(bool, "only-localhost", "Only listen on the localhost interface") orelse false;
    const no_broadcast = b.option(bool, "no-broadcast", "Disable client discovery by broadcast to local network") orelse false;
    const only_ipv4 = b.option(bool, "only-ipv4", "Tracy will only accept connections on IPv4 addresses (disable IPv6)") orelse false;
    const no_code_transfer = b.option(bool, "no-code-transfer", "Disable collection of source code") orelse false;
    const no_context_switch = b.option(bool, "no-context-switch", "Disable capture of context switches") orelse false;
    const no_exit = b.option(bool, "no-exit", "Client executable does not exit until all profile data is sent to server") orelse false;
    const no_sampling = b.option(bool, "no-sampling", "Disable call stack sampling") orelse false;
    const no_verify = b.option(bool, "no-verify", "Disable zone validation for C API") orelse false;
    const no_vsync_capture = b.option(bool, "no-vsync-capture", "Disable capture of hardware Vsync events") orelse false;
    const no_frame_image = b.option(bool, "no-frame-image", "Disable the frame image support and its thread") orelse false;
    const no_system_tracing = b.option(bool, "no-system-tracing", "Disable systrace sampling") orelse false;
    const patchable_nopsleds = b.option(bool, "patchable-nopsleds", "Enable nopsleds for efficient patching by system-level tools (e.g. rr)") orelse false;
    const delayed_init = b.option(bool, "delayed-init", "Enable delayed initialization of the library (init on first call)") orelse false;
    const manual_lifetime = b.option(bool, "manual-lifetime", "Enable the manual lifetime management of the profile") orelse false;
    const fibers = b.option(bool, "fibers", "Enable fibers support") orelse false;
    const no_crash_handler = b.option(bool, "no-crash-handler", "Disable crash handling") orelse false;
    const timer_fallback = b.option(bool, "timer-fallback", "Use lower resolution timers") orelse false;
    const libunwind_backtrace = b.option(bool, "libunwind-backtrace", "Use libunwind backtracing where supported") orelse false;
    const symbol_offline_resolve = b.option(bool, "symbol-offline-resolve", "Instead of full runtime symbol resolution, only resolve the image path and offset to enable offline symbol resolution") orelse false;
    const libbacktrace_elf_dynload_support = b.option(bool, "libbacktrace-elf-dynload-support", "Enable libbacktrace to support dynamically loaded elfs in symbol resolution resolution after the first symbol resolve operation") orelse false;

    // https://ziglang.org/download/0.12.0/release-notes.html#System-Package-Mode
    // Run `zig build --help` and move to the "System Integration Options" section to find more information about system integration.
    const link_system_glfw = b.systemIntegrationOption("glfw", .{});
    const link_system_zstd = b.systemIntegrationOption("zstd", .{});
    const link_system_capstone = b.systemIntegrationOption("capstone", .{});
    const link_system_lz4 = b.systemIntegrationOption("lz4", .{});
    const link_system_freetype = b.systemIntegrationOption("freetype", .{});
    const link_system_curl = b.systemIntegrationOption("curl", .{});

    const common_module_options: std.Build.Module.CreateOptions = .{
        .target = target,
        .optimize = optimize,
        .pic = pie,
        .strip = strip,
    };

    const rpmalloc = createRpcmalloc(b, common_module_options);
    const lz4 = if (link_system_lz4) null else if (b.lazyDependency("lz4", .{
        .target = target,
        .optimize = optimize,
    })) |dependency| dependency.artifact("lz4") else null;

    const tracy_client = b.addLibrary(.{
        .linkage = linkage,
        .name = "tracy",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = pie,
            .strip = strip,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    if (link_system_lz4) tracy_client.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| tracy_client.root_module.linkLibrary(compile);
    tracy_client.root_module.linkLibrary(rpmalloc);
    tracy_client.installHeadersDirectory(b.path("public/client"), "client", .{ .include_extensions = &.{ ".h", ".hpp" } });
    tracy_client.installHeadersDirectory(b.path("public/common"), "common", .{ .include_extensions = &.{ ".h", ".hpp" } });
    tracy_client.installHeadersDirectory(b.path("public/tracy"), "tracy", .{ .include_extensions = &.{ ".h", ".hpp" } });
    tracy_client.root_module.addCSourceFile(.{
        .file = b.path("public/TracyClient.cpp"),
        .flags = &.{ "-std=c++11", "-fno-sanitize=undefined" },
    });
    if (target.result.os.tag == .windows) {
        tracy_client.root_module.linkSystemLibrary("ws2_32", .{});
        tracy_client.root_module.linkSystemLibrary("dbghelp", .{});
        tracy_client.root_module.linkSystemLibrary("advapi32", .{});
        tracy_client.root_module.linkSystemLibrary("user32", .{});
    }
    if (target.result.os.tag == .freebsd) {
        tracy_client.root_module.linkSystemLibrary("execinfo", .{});
    }

    b.installArtifact(tracy_client);

    if (enable) tracy_client.root_module.addCMacro("TRACY_ENABLE", "1");
    if (on_demand) tracy_client.root_module.addCMacro("TRACY_ON_DEMAND", "1");
    if (callstack > 0) tracy_client.root_module.addCMacro("TRACY_CALLSTACK", b.fmt("{d}", .{callstack}));
    if (no_callstack) tracy_client.root_module.addCMacro("TRACY_NO_CALLSTACK", "1");
    if (no_callstack_inlines) tracy_client.root_module.addCMacro("TRACY_NO_CALLSTACK_INLINES", "1");
    if (only_localhost) tracy_client.root_module.addCMacro("TRACY_ONLY_LOCALHOST", "1");
    if (no_broadcast) tracy_client.root_module.addCMacro("TRACY_NO_BROADCAST", "1");
    if (only_ipv4) tracy_client.root_module.addCMacro("TRACY_ONLY_IPV4", "1");
    if (no_code_transfer) tracy_client.root_module.addCMacro("TRACY_NO_CODE_TRANSFER", "1");
    if (no_context_switch) tracy_client.root_module.addCMacro("TRACY_NO_CONTEXT_SWITCH", "1");
    if (no_exit) tracy_client.root_module.addCMacro("TRACY_NO_EXIT", "1");
    if (no_sampling) tracy_client.root_module.addCMacro("TRACY_NO_SAMPLING", "1");
    if (no_verify) tracy_client.root_module.addCMacro("TRACY_NO_VERIFY", "1");
    if (no_vsync_capture) tracy_client.root_module.addCMacro("TRACY_NO_VSYNC_CAPTURE", "1");
    if (no_frame_image) tracy_client.root_module.addCMacro("TRACY_NO_FRAME_IMAGE", "1");
    if (no_system_tracing) tracy_client.root_module.addCMacro("TRACY_NO_SYSTEM_TRACING", "1");
    if (patchable_nopsleds) tracy_client.root_module.addCMacro("TRACY_PATCHABLE_NOPSLEDS", "1");
    if (delayed_init) tracy_client.root_module.addCMacro("TRACY_DELAYED_INIT", "1");
    if (manual_lifetime) tracy_client.root_module.addCMacro("TRACY_MANUAL_LIFETIME", "1");
    if (fibers) tracy_client.root_module.addCMacro("TRACY_FIBERS", "1");
    if (no_crash_handler) tracy_client.root_module.addCMacro("TRACY_NO_CRASH_HANDLER", "1");
    if (timer_fallback) tracy_client.root_module.addCMacro("TRACY_TIMER_FALLBACK", "1");
    if (libunwind_backtrace) tracy_client.root_module.addCMacro("TRACY_LIBUNWIND_BACKTRACE", "1");
    if (symbol_offline_resolve) tracy_client.root_module.addCMacro("TRACY_SYMBOL_OFFLINE_RESOLVE", "1");
    if (libbacktrace_elf_dynload_support) tracy_client.root_module.addCMacro("TRACY_LIBBACKTRACE_ELF_DYNLOAD_SUPPORT", "1");

    // Profiler / Server Options
    const no_fileselector = b.option(bool, "no-fileselector", "Disable the file selector") orelse false;
    const portal = b.option(bool, "portal", "Use xdg-desktop-portal instead of GTK") orelse true; // upstream uses gtk as the default
    const legacy = b.option(bool, "legacy", "Instead of Wayland, use the legacy X11 backend on Linux") orelse false;
    const no_statistics = b.option(bool, "no-statistics", "Disable calculation of statistics") orelse false;
    const self_profile = b.option(bool, "self-profile", "Enable self-profiling") orelse false;
    const no_parallel_stl = b.option(bool, "no-parallel-stl", "Disable parallel STL") orelse true;

    const use_wayland = target.result.os.tag == .linux and !legacy;

    const ini = createIni(b, common_module_options);
    const base64 = createBase64(b, common_module_options);
    const md4c = createMd4c(b, common_module_options);
    const pugixml = createPugixml(b, common_module_options);
    const tidy = createTidyHtml5(b, common_module_options);
    const imgui = createImgui(b, common_module_options, legacy, link_system_glfw, link_system_freetype);
    const zstd = if (link_system_zstd) null else if (b.lazyDependency("zstd", .{
        .target = target,
        .optimize = optimize,
    })) |dependency| dependency.artifact("zstd") else null;
    const capstone = if (link_system_capstone) null else if (b.lazyDependency("capstone", .{
        .target = target,
        .optimize = optimize,
    })) |dependency| dependency.artifact("capstone") else null;
    const curl: ?*std.Build.Step.Compile = blk: {
        if (link_system_curl) break :blk null;
        const dependency = b.lazyDependency("curl", .{
            .target = target,
            .optimize = optimize,
            .libpsl = false,
            .libssh2 = false,
            .libidn2 = false,
            .nghttp2 = false,
            .@"disable-ldap" = true,
            .@"enable-ssl" = false,
        }) orelse break :blk null;
        const curl_build = b.lazyImport(@This(), "curl") orelse break :blk null;
        break :blk curl_build.artifact(dependency, .lib);
    };
    const nfd = if (no_fileselector) null else if (b.lazyDependency("nativefiledialog_extended", .{
        .target = target,
        .optimize = optimize,
        .portal = portal,
    })) |dependency| dependency.artifact("nfd") else null;

    const tracy_server = b.addLibrary(.{
        .linkage = linkage,
        .name = "tracy-server",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = pie,
            .strip = strip,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    tracy_server.root_module.linkLibrary(rpmalloc);
    if (link_system_zstd) tracy_server.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| tracy_server.root_module.linkLibrary(compile);
    if (link_system_lz4) tracy_server.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| tracy_server.root_module.linkLibrary(compile);
    if (link_system_capstone) tracy_server.root_module.linkSystemLibrary("capstone", .{}) else if (capstone) |compile| tracy_server.root_module.linkLibrary(compile);
    if (target.result.os.tag == .windows) tracy_server.root_module.linkSystemLibrary("ws2_32", .{});
    if (no_parallel_stl) tracy_server.root_module.addCMacro("NO_PARALLEL_SORT", "1");
    if (no_statistics) tracy_server.root_module.addCMacro("TRACY_NO_STATISTICS", "1");
    tracy_server.root_module.addIncludePath(b.dependency("pdqsort", .{}).path(""));
    tracy_server.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include"));
    tracy_server.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include"));
    tracy_server.root_module.addIncludePath(b.dependency("xxHash", .{}).path(""));
    tracy_server.root_module.addCSourceFiles(.{
        .root = b.path("server"),
        .flags = &.{ "-std=c++20", "-fno-sanitize=undefined" },
        .files = &.{
            "TracyMemory.cpp",
            "TracyMmap.cpp",
            "TracyPrint.cpp",
            "TracySysUtil.cpp",
            "TracyTaskDispatch.cpp",
            "TracyTextureCompression.cpp",
            "TracyThreadCompress.cpp",
            "TracyWorker.cpp",
        },
    });
    tracy_server.root_module.addCSourceFiles(.{
        .root = b.path("public/common"),
        .flags = &.{ "-std=c++17", "-fno-sanitize=undefined" },
        .files = &.{
            "TracySocket.cpp",
            "TracyStackFrames.cpp",
            "TracySystem.cpp",
        },
    });

    const git_ref_file = b.addWriteFiles().add("GitRef.hpp", "#pragma once\nnamespace tracy { static inline const char* GitRef = \"unknown\"; }");

    const tracy_profiler = b.addExecutable(.{
        .name = "tracy-profiler",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = pie,
            .strip = strip,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    tracy_profiler.root_module.linkLibrary(ini);
    tracy_profiler.root_module.linkLibrary(base64);
    tracy_profiler.root_module.linkLibrary(md4c);
    tracy_profiler.root_module.linkLibrary(pugixml);
    tracy_profiler.root_module.linkLibrary(tidy);
    tracy_profiler.root_module.linkLibrary(imgui);
    tracy_profiler.root_module.linkLibrary(tracy_server);
    tracy_profiler.root_module.linkLibrary(tracy_server);
    tracy_profiler.root_module.addCMacro("BASE64_STATIC_DEFINE", "");
    if (link_system_curl) {
        // TODO If `linkSystemLibrary` select a static library, `CURL_STATICLIB` will not be defined.
        tracy_profiler.root_module.linkSystemLibrary("curl", .{});
    } else if (curl) |compile| {
        tracy_profiler.root_module.addCMacro("CURL_STATICLIB", "");
        tracy_profiler.root_module.linkLibrary(compile);
    }
    if (link_system_zstd) tracy_profiler.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| tracy_profiler.root_module.linkLibrary(compile);
    if (link_system_lz4) tracy_profiler.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| tracy_profiler.root_module.linkLibrary(compile);
    if (link_system_capstone) tracy_profiler.root_module.linkSystemLibrary("capstone", .{}) else if (capstone) |compile| tracy_profiler.root_module.linkLibrary(compile);
    if (no_parallel_stl) tracy_profiler.root_module.addCMacro("NO_PARALLEL_SORT", "1");
    if (no_fileselector) {
        tracy_profiler.root_module.addCMacro("TRACY_NO_FILESELECTOR", "1");
    } else {
        if (nfd) |compile| tracy_profiler.root_module.linkLibrary(compile);
    }
    tracy_profiler.root_module.addCMacro("__DATE__", "\"??? ?? ????\"");
    tracy_profiler.root_module.addCMacro("__TIME__", "\"??:??:??\"");
    tracy_profiler.root_module.addIncludePath(b.path("server"));
    tracy_profiler.root_module.addIncludePath(b.path("include"));
    tracy_profiler.root_module.addIncludePath(b.dependency("dtl", .{}).path(""));
    tracy_profiler.root_module.addIncludePath(b.dependency("stb", .{}).path(""));
    tracy_profiler.root_module.addIncludePath(b.dependency("pdqsort", .{}).path(""));
    tracy_profiler.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include"));
    tracy_profiler.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include"));
    tracy_profiler.root_module.addIncludePath(b.dependency("xxHash", .{}).path(""));
    tracy_profiler.root_module.addIncludePath(b.dependency("nlohmann_json", .{}).path("single_include"));
    tracy_profiler.root_module.addIncludePath(b.dependency("usearch", .{}).path("include"));
    tracy_profiler.root_module.addIncludePath(b.dependency("f16", .{}).path("include"));
    tracy_profiler.root_module.addIncludePath(git_ref_file.dirname());
    tracy_profiler.root_module.addCSourceFiles(.{
        .root = b.path("profiler/src/profiler"),
        .flags = &.{ "-std=c++20", "-fno-sanitize=undefined" },
        .files = &.{
            "TracyAchievementData.cpp",
            "TracyAchievements.cpp",
            "TracyBadVersion.cpp",
            "TracyColor.cpp",
            "TracyConfig.cpp",
            "TracyEmbed.cpp",
            "TracyEventDebug.cpp",
            "TracyFileselector.cpp",
            "TracyFilesystem.cpp",
            "TracyImGui.cpp",
            "TracyMarkdown.cpp",
            "TracyMicroArchitecture.cpp",
            "TracyMouse.cpp",
            "TracyProtoHistory.cpp",
            "TracySourceContents.cpp",
            "TracySourceTokenizer.cpp",
            "TracySourceView.cpp",
            "TracyStorage.cpp",
            "TracyTexture.cpp",
            "TracyTimelineController.cpp",
            "TracyTimelineItem.cpp",
            "TracyTimelineItemCpuData.cpp",
            "TracyTimelineItemGpu.cpp",
            "TracyTimelineItemPlot.cpp",
            "TracyTimelineItemThread.cpp",
            "TracyUserData.cpp",
            "TracyUtility.cpp",
            "TracyView.cpp",
            "TracyView_Annotations.cpp",
            "TracyView_Callstack.cpp",
            "TracyView_Compare.cpp",
            "TracyView_ConnectionState.cpp",
            "TracyView_ContextSwitch.cpp",
            "TracyView_CpuData.cpp",
            "TracyView_FindZone.cpp",
            "TracyView_FlameGraph.cpp",
            "TracyView_FrameOverview.cpp",
            "TracyView_FrameTimeline.cpp",
            "TracyView_FrameTree.cpp",
            "TracyView_GpuTimeline.cpp",
            "TracyView_Locks.cpp",
            "TracyView_Memory.cpp",
            "TracyView_Messages.cpp",
            "TracyView_Navigation.cpp",
            "TracyView_NotificationArea.cpp",
            "TracyView_Options.cpp",
            "TracyView_Playback.cpp",
            "TracyView_Plots.cpp",
            "TracyView_Ranges.cpp",
            "TracyView_Samples.cpp",
            "TracyView_Statistics.cpp",
            "TracyView_Timeline.cpp",
            "TracyView_TraceInfo.cpp",
            "TracyView_Utility.cpp",
            "TracyView_ZoneInfo.cpp",
            "TracyView_ZoneTimeline.cpp",
            "TracyWeb.cpp",
        },
    });
    tracy_profiler.root_module.addCSourceFiles(.{
        .root = b.path("profiler/src/profiler"),
        .flags = &.{ "-std=c++20", "-fno-sanitize=undefined" },
        .files = &.{
            "TracyLlm.cpp",
            "TracyLlmApi.cpp",
            "TracyLlmChat.cpp",
            "TracyLlmEmbeddings.cpp",
            "TracyLlmTools.cpp",
        },
    });
    tracy_profiler.root_module.addCSourceFiles(.{
        .root = b.path("profiler/src"),
        .flags = &.{ "-std=c++20", "-fno-sanitize=undefined" },
        .files = &.{
            "ConnectionHistory.cpp",
            "Filters.cpp",
            "Fonts.cpp",
            "HttpRequest.cpp",
            "ImGuiContext.cpp",
            "IsElevated.cpp",
            "main.cpp",
            "ResolvService.cpp",
            "RunQueue.cpp",
            "WindowPosition.cpp",
            "winmain.cpp",
            "winmainArchDiscovery.cpp",
            if (use_wayland) "BackendWayland.cpp" else "BackendGlfw.cpp",
        },
    });
    tracy_profiler.root_module.addWin32ResourceFile(.{ .file = b.path("profiler/win32/Tracy.rc") });

    // unum-cloud/USearch includes `Windows.h` but Zig provides
    // `windows.h` which is problematic when cross compiling
    // from a case-sensitive filesystem.
    // https://github.com/llvm/llvm-project/issues/161400
    if (target.result.os.tag == .windows and b.graph.host.result.os.tag != .windows) {
        const upper_case_windows_h = b.addWriteFiles().add("Windows.h", "#include <windows.h>");
        tracy_profiler.root_module.addIncludePath(upper_case_windows_h.dirname());
    }

    const embed_exe = b.addExecutable(.{
        .name = "embed",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = std.builtin.OptimizeMode.ReleaseSafe,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    if (link_system_lz4) {
        embed_exe.root_module.linkSystemLibrary("lz4", .{});
    } else if (b.lazyDependency("lz4", .{
        .target = b.graph.host,
        .optimize = std.builtin.OptimizeMode.ReleaseSafe,
    })) |dependency| {
        embed_exe.root_module.linkLibrary(dependency.artifact("lz4"));
    }
    embed_exe.addCSourceFile(.{
        .file = b.path("profiler/helpers/embed.cpp"),
        .flags = &.{"-std=c++20"},
    });

    for (
        [_][]const u8{
            "SystemPrompt",
            "SystemReminder",
            "FontFixed",
            "FontIcons",
            "FontNormal",
            "FontBold",
            "FontItalic",
            "FontBoldItalic",
            "Manual",
        },
        [_]std.Build.LazyPath{
            b.path("profiler/src/llm/system.prompt.md"),
            b.path("profiler/src/llm/system.reminder.md"),
            b.path("profiler/src/font/FiraCode-Retina.ttf"),
            b.path("profiler/src/font/Font Awesome 6 Free-Solid-900.otf"),
            b.path("profiler/src/font/Roboto-Regular.ttf"),
            b.path("profiler/src/font/Roboto-Bold.ttf"),
            b.path("profiler/src/font/Roboto-Italic.ttf"),
            b.path("profiler/src/font/Roboto-BoldItalic.ttf"),
            b.path("manual/tracy.md"),
        },
    ) |name, file| {
        const run_embed = b.addRunArtifact(embed_exe);
        run_embed.clearEnvironment();
        run_embed.addArg(name);
        run_embed.addFileArg(file);
        const output_file = run_embed.addOutputFileArg(b.fmt("data/{s}", .{name}));
        tracy_profiler.root_module.addIncludePath(output_file.dirname().dirname());
        tracy_profiler.root_module.addCSourceFile(.{
            .file = output_file.path(b, b.fmt("../{s}.cpp", .{name})),
        });
    }

    if (use_wayland) {
        const link_system_libxkbcommon = b.systemIntegrationOption("libxkbcommon", .{ .default = true });

        if (link_system_libxkbcommon) {
            tracy_profiler.root_module.linkSystemLibrary("xkbcommon", .{});
        } else {
            const xkb_config_root = b.option(
                []const u8,
                "xkb-config-root",
                "The XKB config root. Most distributions use '/usr/share/X11/xkb'",
            ) orelse @panic("The 'xkb-config-root' config option must be specified when using non-system provided libxkbcommon.");

            const x_locale_root = b.option(
                []const u8,
                "x-locale-root",
                "The X locale root. Most distributions use '/usr/share/X11/locale'",
            ) orelse @panic("The 'x-locale-root' config option must be specified when using non-system provided libxkbcommon.");

            if (b.lazyDependency("libxkbcommon", .{
                .target = target,
                .optimize = optimize,
                .@"xkb-config-root" = xkb_config_root,
                .@"x-locale-root" = x_locale_root,
            })) |wayland| {
                tracy_profiler.root_module.linkLibrary(wayland.artifact("xkbcommon"));
            }
        }

        for ([_][]const u8{
            "wayland-client", // linking wayland-egl will most likely link wayland-client to this should be avoided
            "wayland-cursor",
            "wayland-egl",
        }) |name| {
            if (b.systemIntegrationOption(name, .{})) {
                tracy_profiler.root_module.linkSystemLibrary(name, .{});
            } else if (b.lazyDependency("wayland", .{
                .target = target,
                .optimize = optimize,
            })) |wayland| {
                tracy_profiler.root_module.linkLibrary(wayland.artifact(name));
            }
        }

        const use_system_wayland_scanner = b.systemIntegrationOption("wayland-scanner", .{});
        const host_wayland = if (!use_system_wayland_scanner)
            b.lazyDependency("wayland", .{
                .target = b.graph.host,
                .optimize = std.builtin.OptimizeMode.Debug,
            })
        else
            null;

        const use_system_wayland_protocols = b.systemIntegrationOption("wayland-protocols", .{});

        const wayland_protocols_dir: ?std.Build.LazyPath = if (use_system_wayland_protocols) blk: {
            var code: u8 = undefined;
            const pkgdatadir = if (b.runAllowFail(&[_][]const u8{
                b.graph.env_map.get("PKG_CONFIG") orelse "pkg-config",
                "wayland-protocols",
                "--variable=pkgdatadir",
            }, &code, .Ignore)) |stdout| stdout else |err| switch (err) {
                error.ProcessTerminated => return error.PkgConfigCrashed,
                error.ExecNotSupported => return error.PkgConfigFailed,
                error.ExitCodeFailure => return error.PkgConfigFailed,
                error.FileNotFound => return error.PkgConfigNotInstalled,
                else => return err,
            };
            break :blk .{ .cwd_relative = std.mem.trim(u8, pkgdatadir, &std.ascii.whitespace) };
        } else if (b.lazyDependency("wayland_protocols", .{})) |wayland_protocols| wayland_protocols.path(".") else null;

        if (wayland_protocols_dir) |wayland_protocols| {
            for (
                [_][]const u8{
                    "staging/xdg-activation/xdg-activation-v1.xml",
                    "unstable/xdg-decoration/xdg-decoration-unstable-v1.xml",
                    "stable/xdg-shell/xdg-shell.xml",
                    "staging/fractional-scale/fractional-scale-v1.xml",
                    "stable/viewporter/viewporter.xml",
                    "staging/cursor-shape/cursor-shape-v1.xml",
                    "stable/tablet/tablet-v2.xml",
                    "staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml",
                },
                [_][]const u8{
                    "wayland-xdg-activation",
                    "wayland-xdg-decoration",
                    "wayland-xdg-shell",
                    "wayland-fractional-scale",
                    "wayland-viewporter",
                    "wayland-cursor-shape",
                    "wayland-tablet",
                    "wayland-xdg-toplevel-icon",
                },
            ) |input_file, output_filename| {
                const run_wayland_scanner1: *std.Build.Step.Run = .create(b, "run wayland-scanner");
                const run_wayland_scanner2: *std.Build.Step.Run = .create(b, "run wayland-scanner");
                if (use_system_wayland_scanner) {
                    run_wayland_scanner1.addArg("wayland-scanner");
                    run_wayland_scanner2.addArg("wayland-scanner");
                } else if (host_wayland) |wayland_host| {
                    run_wayland_scanner1.addArtifactArg(wayland_host.artifact("wayland-scanner"));
                    run_wayland_scanner2.addArtifactArg(wayland_host.artifact("wayland-scanner"));
                }

                {
                    run_wayland_scanner1.addArg("client-header");
                    run_wayland_scanner1.addFileArg(wayland_protocols.path(b, input_file));
                    const header_file = run_wayland_scanner1.addOutputFileArg(b.fmt("{s}-client-protocol.h", .{output_filename}));
                    tracy_profiler.root_module.addIncludePath(header_file.dirname());
                }

                {
                    run_wayland_scanner2.addArg("public-code");
                    run_wayland_scanner2.addFileArg(wayland_protocols.path(b, input_file));
                    const source_file = run_wayland_scanner2.addOutputFileArg(b.fmt("{s}.c", .{output_filename}));
                    tracy_profiler.root_module.addCSourceFile(.{ .file = source_file });
                }
            }
        }
    } else {
        if (link_system_glfw) {
            tracy_profiler.root_module.linkSystemLibrary("glfw3", .{});
        } else {
            if (b.lazyDependency("glfw", .{
                .target = target,
                .optimize = optimize,
                .x11 = if (target.result.os.tag == .linux) legacy else true,
                .wayland = true,
            })) |glfw_dependency| {
                tracy_profiler.root_module.linkLibrary(glfw_dependency.artifact("glfw"));
            }
        }
    }

    if (self_profile) tracy_profiler.root_module.addCMacro("TRACY_ENABLE", "1");
    if (on_demand) tracy_profiler.root_module.addCMacro("TRACY_ON_DEMAND", "1");
    if (callstack > 0) tracy_profiler.root_module.addCMacro("TRACY_CALLSTACK", b.fmt("{d}", .{callstack}));
    if (no_callstack) tracy_profiler.root_module.addCMacro("TRACY_NO_CALLSTACK", "1");
    if (no_callstack_inlines) tracy_profiler.root_module.addCMacro("TRACY_NO_CALLSTACK_INLINES", "1");
    if (only_localhost) tracy_profiler.root_module.addCMacro("TRACY_ONLY_LOCALHOST", "1");
    if (no_broadcast) tracy_profiler.root_module.addCMacro("TRACY_NO_BROADCAST", "1");
    if (only_ipv4) tracy_profiler.root_module.addCMacro("TRACY_ONLY_IPV4", "1");
    if (no_code_transfer) tracy_profiler.root_module.addCMacro("TRACY_NO_CODE_TRANSFER", "1");
    if (no_context_switch) tracy_profiler.root_module.addCMacro("TRACY_NO_CONTEXT_SWITCH", "1");
    if (no_exit) tracy_profiler.root_module.addCMacro("TRACY_NO_EXIT", "1");
    if (no_sampling) tracy_profiler.root_module.addCMacro("TRACY_NO_SAMPLING", "1");
    if (no_verify) tracy_profiler.root_module.addCMacro("TRACY_NO_VERIFY", "1");
    if (no_vsync_capture) tracy_profiler.root_module.addCMacro("TRACY_NO_VSYNC_CAPTURE", "1");
    if (no_frame_image) tracy_profiler.root_module.addCMacro("TRACY_NO_FRAME_IMAGE", "1");
    if (no_system_tracing) tracy_profiler.root_module.addCMacro("TRACY_NO_SYSTEM_TRACING", "1");
    if (patchable_nopsleds) tracy_profiler.root_module.addCMacro("TRACY_PATCHABLE_NOPSLEDS", "1");
    if (delayed_init) tracy_profiler.root_module.addCMacro("TRACY_DELAYED_INIT", "1");
    if (manual_lifetime) tracy_profiler.root_module.addCMacro("TRACY_MANUAL_LIFETIME", "1");
    if (fibers) tracy_profiler.root_module.addCMacro("TRACY_FIBERS", "1");
    if (no_crash_handler) tracy_profiler.root_module.addCMacro("TRACY_NO_CRASH_HANDLER", "1");
    if (timer_fallback) tracy_profiler.root_module.addCMacro("TRACY_TIMER_FALLBACK", "1");
    if (libunwind_backtrace) tracy_profiler.root_module.addCMacro("TRACY_LIBUNWIND_BACKTRACE", "1");
    if (symbol_offline_resolve) tracy_profiler.root_module.addCMacro("TRACY_SYMBOL_OFFLINE_RESOLVE", "1");
    if (libbacktrace_elf_dynload_support) tracy_profiler.root_module.addCMacro("TRACY_LIBBACKTRACE_ELF_DYNLOAD_SUPPORT", "1");

    const install_profiler = b.addInstallArtifact(tracy_profiler, .{});
    b.getInstallStep().dependOn(&install_profiler.step);

    const install_profiler_step = b.step("install-profiler", "Only install the tracy-profiler to prefix path");
    install_profiler_step.dependOn(&install_profiler.step);

    const run_cmd = b.addRunArtifact(tracy_profiler);
    run_cmd.step.dependOn(&install_profiler.step);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run Tracy Profiler");
    run_step.dependOn(&run_cmd.step);

    {
        const capture_exe = b.addExecutable(.{
            .name = "tracy-capture",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .pic = pie,
                .strip = strip,
                .link_libc = true,
                .link_libcpp = true,
            }),
        });
        if (link_system_zstd) capture_exe.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| capture_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (link_system_lz4) capture_exe.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| capture_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        capture_exe.root_module.linkLibrary(tracy_server);
        if (no_statistics) capture_exe.root_module.addCMacro("NO_STATISTICS", "1");
        if (no_parallel_stl) capture_exe.root_module.addCMacro("NO_PARALLEL_SORT", "1");
        capture_exe.root_module.addCSourceFile(.{
            .file = b.path("capture/src/capture.cpp"),
            .flags = &.{"-std=c++20"},
        });
        if (target.result.os.tag == .windows) {
            const getopt_port = b.dependency("getopt_port", .{});
            capture_exe.root_module.addIncludePath(getopt_port.path(""));
        }
        capture_exe.root_module.addIncludePath(b.dependency("pdqsort", .{}).path("")); // dependency of tracy-server
        capture_exe.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include")); // dependency of tracy-server
        capture_exe.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include")); // dependency of tracy-server
        capture_exe.root_module.addIncludePath(b.dependency("xxHash", .{}).path("")); // dependency of tracy-server

        if (no_statistics) {
            capture_exe.root_module.addCMacro("TRACY_NO_STATISTICS", "1");
        }

        const install_capture_exe = b.addInstallArtifact(capture_exe, .{});
        b.getInstallStep().dependOn(&install_capture_exe.step);

        const run_capture = b.addRunArtifact(capture_exe);
        run_capture.step.dependOn(&install_capture_exe.step);

        if (b.args) |args| {
            run_capture.addArgs(args);
        }

        const run_capture_step = b.step("capture", "Run capture.cpp");
        run_capture_step.dependOn(&run_capture.step);
    }

    {
        const csvexport_exe = b.addExecutable(.{
            .name = "tracy-csvexport",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .pic = pie,
                .strip = strip,
                .link_libc = true,
                .link_libcpp = true,
            }),
        });
        if (link_system_zstd) csvexport_exe.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| csvexport_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (link_system_lz4) csvexport_exe.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| csvexport_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        csvexport_exe.root_module.linkLibrary(tracy_server);
        csvexport_exe.root_module.addCMacro("NO_STATISTICS", "1");
        if (no_parallel_stl) csvexport_exe.root_module.addCMacro("NO_PARALLEL_SORT", "1");
        csvexport_exe.root_module.addCSourceFile(.{
            .file = b.path("csvexport/src/csvexport.cpp"),
            .flags = &.{"-std=c++20"},
        });
        csvexport_exe.root_module.addIncludePath(b.dependency("getopt_port", .{}).path(""));
        csvexport_exe.root_module.addIncludePath(b.dependency("pdqsort", .{}).path("")); // dependency of tracy-server
        csvexport_exe.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include")); // dependency of tracy-server
        csvexport_exe.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include")); // dependency of tracy-server
        csvexport_exe.root_module.addIncludePath(b.dependency("xxHash", .{}).path("")); // dependency of tracy-server

        const install_csvexport_exe = b.addInstallArtifact(csvexport_exe, .{});
        b.getInstallStep().dependOn(&install_csvexport_exe.step);

        const run_csvexport = b.addRunArtifact(csvexport_exe);
        run_csvexport.step.dependOn(&install_csvexport_exe.step);

        if (b.args) |args| {
            run_csvexport.addArgs(args);
        }

        const run_csvexport_step = b.step("csvexport", "Run csvexport.cpp");
        run_csvexport_step.dependOn(&run_csvexport.step);
    }

    {
        const import_chrome_exe = b.addExecutable(.{
            .name = "tracy-import-chrome",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .pic = pie,
                .strip = strip,
                .link_libc = true,
                .link_libcpp = true,
            }),
        });
        if (link_system_zstd) import_chrome_exe.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| import_chrome_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (link_system_lz4) import_chrome_exe.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| import_chrome_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        import_chrome_exe.root_module.linkLibrary(tracy_server);
        if (no_statistics) import_chrome_exe.root_module.addCMacro("NO_STATISTICS", "1");
        if (no_parallel_stl) import_chrome_exe.root_module.addCMacro("NO_PARALLEL_SORT", "1");
        import_chrome_exe.root_module.addCSourceFile(.{
            .file = b.path("import/src/import-chrome.cpp"),
            .flags = &.{"-std=c++20"},
        });
        import_chrome_exe.root_module.addIncludePath(b.dependency("nlohmann_json", .{}).path("single_include"));
        import_chrome_exe.root_module.addIncludePath(b.dependency("pdqsort", .{}).path("")); // dependency of tracy-server
        import_chrome_exe.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include")); // dependency of tracy-server
        import_chrome_exe.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include")); // dependency of tracy-server
        import_chrome_exe.root_module.addIncludePath(b.dependency("xxHash", .{}).path("")); // dependency of tracy-server

        const install_import_chrome_exe = b.addInstallArtifact(import_chrome_exe, .{});
        b.getInstallStep().dependOn(&install_import_chrome_exe.step);

        const run_import_chrome = b.addRunArtifact(import_chrome_exe);
        run_import_chrome.step.dependOn(&install_import_chrome_exe.step);

        if (b.args) |args| {
            run_import_chrome.addArgs(args);
        }

        const run_import_chrome_step = b.step("import-chrome", "Run import-chrome.cpp");
        run_import_chrome_step.dependOn(&run_import_chrome.step);
    }

    {
        const import_fuchsia_exe = b.addExecutable(.{
            .name = "tracy-import-fuchsia",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .pic = pie,
                .strip = strip,
                .link_libc = true,
                .link_libcpp = true,
            }),
        });
        import_fuchsia_exe.root_module.linkLibrary(tracy_server);
        if (link_system_zstd) import_fuchsia_exe.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| import_fuchsia_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (link_system_lz4) import_fuchsia_exe.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| import_fuchsia_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (no_statistics) import_fuchsia_exe.root_module.addCMacro("NO_STATISTICS", "1");
        if (no_parallel_stl) import_fuchsia_exe.root_module.addCMacro("NO_PARALLEL_SORT", "1");
        import_fuchsia_exe.root_module.addCSourceFile(.{
            .file = b.path("import/src/import-fuchsia.cpp"),
            .flags = &.{"-std=c++20"},
        });
        import_fuchsia_exe.root_module.addIncludePath(b.dependency("pdqsort", .{}).path("")); // dependency of tracy-server
        import_fuchsia_exe.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include")); // dependency of tracy-server
        import_fuchsia_exe.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include")); // dependency of tracy-server
        import_fuchsia_exe.root_module.addIncludePath(b.dependency("xxHash", .{}).path("")); // dependency of tracy-server

        const install_import_fuchsia_exe = b.addInstallArtifact(import_fuchsia_exe, .{});
        b.getInstallStep().dependOn(&install_import_fuchsia_exe.step);

        const run_import_fuchsia = b.addRunArtifact(import_fuchsia_exe);
        run_import_fuchsia.step.dependOn(&install_import_fuchsia_exe.step);

        if (b.args) |args| {
            run_import_fuchsia.addArgs(args);
        }

        const run_import_fuchsia_step = b.step("import-fuchsia", "Run import-fuchsia.cpp");
        run_import_fuchsia_step.dependOn(&run_import_fuchsia.step);
    }

    {
        const test_exe = b.addExecutable(.{
            .name = "tracy-test",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .pic = pie,
                .strip = strip,
                .link_libc = true,
                .link_libcpp = true,
            }),
        });
        test_exe.root_module.linkLibrary(tracy_client);
        test_exe.root_module.addCSourceFile(.{
            .file = b.path("test/test.cpp"),
            .flags = &.{"-std=c++11"},
        });
        test_exe.root_module.addIncludePath(b.dependency("stb", .{}).path(""));

        const run_test = b.addRunArtifact(test_exe);
        run_test.setCwd(b.path("test"));

        if (b.args) |args| {
            run_test.addArgs(args);
        }

        const run_test_step = b.step("test", "Run test.cpp");
        run_test_step.dependOn(&run_test.step);
    }

    {
        const update_exe = b.addExecutable(.{
            .name = "tracy-update",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .pic = pie,
                .strip = strip,
                .link_libc = true,
                .link_libcpp = true,
            }),
        });
        update_exe.root_module.linkLibrary(tracy_server);
        if (link_system_zstd) update_exe.root_module.linkSystemLibrary("zstd", .{}) else if (zstd) |compile| update_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (link_system_lz4) update_exe.root_module.linkSystemLibrary("lz4", .{}) else if (lz4) |compile| update_exe.root_module.linkLibrary(compile); // dependency of tracy-server
        if (target.result.os.tag == .windows) update_exe.root_module.linkSystemLibrary("dbghelp", .{});
        if (no_statistics) update_exe.root_module.addCMacro("NO_STATISTICS", "1");
        if (no_parallel_stl) update_exe.root_module.addCMacro("NO_PARALLEL_SORT", "1");
        update_exe.root_module.addIncludePath(b.path(""));
        update_exe.root_module.addCSourceFiles(.{
            .root = b.path("update/src"),
            .files = &.{
                "OfflineSymbolResolver.cpp",
                "OfflineSymbolResolverAddr2Line.cpp",
                "OfflineSymbolResolverDbgHelper.cpp",
                "update.cpp",
            },
            .flags = &.{"-std=c++20"},
        });
        update_exe.root_module.addIncludePath(b.dependency("getopt_port", .{}).path(""));
        update_exe.root_module.addIncludePath(b.dependency("pdqsort", .{}).path("")); // dependency of tracy-server
        update_exe.root_module.addIncludePath(b.dependency("ppqsort", .{}).path("include")); // dependency of tracy-server
        update_exe.root_module.addIncludePath(b.dependency("robin_hood_hashing", .{}).path("src/include")); // dependency of tracy-server
        update_exe.root_module.addIncludePath(b.dependency("xxHash", .{}).path("")); // dependency of tracy-server

        const install_update_exe = b.addInstallArtifact(update_exe, .{});
        b.getInstallStep().dependOn(&install_update_exe.step);

        const run_update = b.addRunArtifact(update_exe);
        run_update.step.dependOn(&install_update_exe.step);

        if (b.args) |args| {
            run_update.addArgs(args);
        }

        const run_update_step = b.step("update", "Run update.cpp");
        run_update_step.dependOn(&run_update.step);
    }
}

fn createIni(b: *std.Build, options: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const upstream = b.dependency("ini", .{});
    const ini = b.addLibrary(.{
        .linkage = .static,
        .name = "ini",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
        }),
    });
    ini.installHeader(upstream.path("src/ini.h"), "ini.h");
    ini.root_module.addIncludePath(upstream.path("src"));
    ini.root_module.addCSourceFile(.{ .file = upstream.path("src/ini.c") });
    return ini;
}

fn createRpcmalloc(b: *std.Build, options: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const upstream = b.dependency("rpmalloc", .{});
    const rpmalloc = b.addLibrary(.{
        .linkage = .static,
        .name = "rpmalloc",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
        }),
    });
    rpmalloc.installHeadersDirectory(upstream.path("rpmalloc"), "rpmalloc", .{});
    rpmalloc.root_module.addIncludePath(upstream.path("rpmalloc"));
    rpmalloc.root_module.addCSourceFile(.{ .file = upstream.path("rpmalloc/rpmalloc.c") });

    if (options.target.?.result.os.tag.isDarwin() and options.target.?.result.os.tag != .ios) {
        // Zig doesn't bundle `mach_vm.h` but it is unneeded anyway.
        const write_files = b.addWriteFiles();
        const fake_mach_vm = write_files.add("mach/mach_vm.h", "");
        rpmalloc.root_module.addIncludePath(fake_mach_vm.dirname().dirname());
    }
    return rpmalloc;
}

fn createImgui(
    b: *std.Build,
    options: std.Build.Module.CreateOptions,
    legacy: bool,
    link_system_glfw: bool,
    link_system_freetype: bool,
) *std.Build.Step.Compile {
    const enable_freetype: bool = false;

    const upstream = b.dependency("imgui", .{});
    const imgui = b.addLibrary(.{
        .linkage = .static,
        .name = "imgui",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    imgui.installHeadersDirectory(upstream.path(""), ".", .{});
    imgui.root_module.addIncludePath(upstream.path(""));
    imgui.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "imgui.cpp",
            "imgui_draw.cpp",
            "imgui_tables.cpp",
            "imgui_widgets.cpp",
        },
    });
    if (link_system_glfw) {
        imgui.root_module.linkSystemLibrary("glfw3", .{});
    } else {
        if (b.lazyDependency("glfw", .{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .x11 = if (options.target.?.result.os.tag == .linux) legacy else true,
            .wayland = true,
        })) |glfw_dependency| {
            imgui.root_module.linkLibrary(glfw_dependency.artifact("glfw"));
        }
    }

    imgui.root_module.addCSourceFiles(.{
        .root = upstream.path("backends"),
        .files = &.{
            "imgui_impl_glfw.cpp",
            "imgui_impl_opengl3.cpp",
        },
    });
    imgui.installHeadersDirectory(upstream.path("backends"), "imgui", .{});
    imgui.root_module.addCMacro("GLFW_INCLUDE_NONE", "1");
    if (imgui.root_module.optimize != .Debug) {
        imgui.root_module.addCMacro("IMGUI_DISABLE_DEBUG_TOOLS", "1");
        imgui.root_module.addCMacro("IMGUI_DISABLE_DEMO_WINDOWS", "1");
    }
    imgui.root_module.addIncludePath(upstream.path("backends"));

    if (enable_freetype) {
        if (link_system_freetype) {
            imgui.root_module.linkSystemLibrary("freetype", .{});
        } else if (b.lazyDependency("freetype", .{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .enable_brotli = false,
        })) |freetype_dependency| {
            imgui.root_module.linkLibrary(freetype_dependency.artifact("freetype"));
        }

        imgui.root_module.addCMacro("IMGUI_ENABLE_FREETYPE", "1");
        imgui.root_module.addIncludePath(upstream.path("misc/freetype"));
        imgui.root_module.addCSourceFile(.{
            .file = upstream.path("misc/freetype/imgui_freetype.cpp"),
        });
    }

    return imgui;
}

fn createBase64(
    b: *std.Build,
    options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const upstream = b.dependency("base64", .{});

    const target = options.target.?.result;
    const config_header = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("cmake/config.h.in") },
    }, .{
        .BASE64_WITH_SSSE3 = target.cpu.arch.isX86() and std.Target.x86.featureSetHas(target.cpu.features, .sse3),
        .BASE64_WITH_SSE41 = target.cpu.arch.isX86() and std.Target.x86.featureSetHas(target.cpu.features, .sse4_1),
        .BASE64_WITH_SSE42 = target.cpu.arch.isX86() and std.Target.x86.featureSetHas(target.cpu.features, .sse4_2),
        .BASE64_WITH_AVX = target.cpu.arch.isX86() and std.Target.x86.featureSetHas(target.cpu.features, .avx),
        .BASE64_WITH_AVX2 = target.cpu.arch.isX86() and std.Target.x86.featureSetHas(target.cpu.features, .avx2),
        .BASE64_WITH_AVX512 = target.cpu.arch.isX86() and std.Target.x86.featureSetHas(target.cpu.features, .avx512vl) and std.Target.x86.featureSetHas(target.cpu.features, .avx512vbmi),
        .BASE64_WITH_NEON32 = false,
        .BASE64_WITH_NEON64 = target.cpu.arch.isAARCH64() and std.Target.aarch64.featureSetHas(target.cpu.features, .neon),
    });

    const base64 = b.addLibrary(.{
        .linkage = .static,
        .name = "base64",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
        }),
    });
    base64.root_module.addConfigHeader(config_header);
    base64.installHeader(upstream.path("include/libbase64.h"), "libbase64.h");
    base64.root_module.addCMacro("BASE64_STATIC_DEFINE", "1");
    base64.root_module.addIncludePath(upstream.path("include"));
    base64.root_module.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = &.{
            "lib.c",
            "codec_choose.c",
            "tables/tables.c",
            "arch/generic/codec.c",

            "arch/ssse3/codec.c",
            "arch/sse41/codec.c",
            "arch/sse42/codec.c",
            "arch/avx/codec.c",
            "arch/avx2/codec.c",
            "arch/avx512/codec.c",

            "arch/neon32/codec.c",
            "arch/neon64/codec.c",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Werror",
        },
    });

    return base64;
}

fn createMd4c(
    b: *std.Build,
    options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const upstream = b.dependency("md4c", .{});
    // TODO Figure out a way to infer the version
    const version: std.SemanticVersion = .{ .major = 0, .minor = 5, .patch = 2 };

    const md4c = b.addLibrary(.{
        .linkage = .static,
        .name = "md4c",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
        }),
    });
    md4c.installHeader(upstream.path("src/md4c.h"), "md4c.h");
    md4c.root_module.addCMacro("MD_VERSION_MAJOR", b.fmt("{d}", .{version.major}));
    md4c.root_module.addCMacro("MD_VERSION_MINOR", b.fmt("{d}", .{version.minor}));
    md4c.root_module.addCMacro("MD_VERSION_RELEASE", b.fmt("{d}", .{version.patch}));
    md4c.root_module.addCSourceFile(.{
        .file = upstream.path("src/md4c.c"),
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Wshadow",
            "-Wdeclaration-after-statement",
        },
    });

    return md4c;
}

fn createPugixml(
    b: *std.Build,
    options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const upstream = b.dependency("pugixml", .{});
    const pugixml = b.addLibrary(.{
        .linkage = .static,
        .name = "pugixml",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    pugixml.installHeader(upstream.path("src/pugiconfig.hpp"), "pugiconfig.hpp");
    pugixml.installHeader(upstream.path("src/pugixml.hpp"), "pugixml.hpp");
    pugixml.root_module.addCSourceFile(.{
        .file = upstream.path("src/pugixml.cpp"),
    });
    return pugixml;
}

fn createTidyHtml5(
    b: *std.Build,
    options: std.Build.Module.CreateOptions,
) *std.Build.Step.Compile {
    const upstream = b.dependency("tidy-html5", .{});

    // TODO Figure out a way to infer the version
    const version_string: []const u8 = "5.9.20";
    const release_date: []const u8 = "2022/01/25";

    const tidy = b.addLibrary(.{
        .linkage = .static,
        .name = "tidy",
        .root_module = b.createModule(.{
            .target = options.target.?,
            .optimize = options.optimize.?,
            .pic = options.pic,
            .strip = options.strip,
            .link_libc = true,
        }),
    });
    tidy.installHeader(upstream.path("include/tidyplatform.h"), "tidyplatform.h");
    tidy.installHeader(upstream.path("include/tidy.h"), "tidy.h");
    tidy.installHeader(upstream.path("include/tidyenum.h"), "tidyenum.h");
    tidy.installHeader(upstream.path("include/tidybuffio.h"), "tidybuffio.h");
    tidy.root_module.addCMacro("_REENTRANT", "");
    if (options.target.?.result.isGnuLibC()) tidy.root_module.addCMacro("SUPPORT_GETPWNAM", "1");
    tidy.root_module.addCMacro("LIBTIDY_VERSION", b.fmt("\"{s}\"", .{version_string}));
    tidy.root_module.addCMacro("RELEASE_DATE", b.fmt("\"{s}\"", .{release_date}));
    tidy.root_module.addIncludePath(upstream.path("include"));
    tidy.root_module.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{
            "access.c",     "attrs.c",    "istack.c",
            "parser.c",     "tags.c",     "entities.c",
            "lexer.c",      "pprint.c",   "charsets.c",
            "clean.c",      "message.c",  "config.c",
            "alloc.c",      "attrdict.c", "buffio.c",
            "fileio.c",     "streamio.c", "tagask.c",
            "tmbstr.c",     "utf8.c",     "tidylib.c",
            "mappedio.c",   "gdoc.c",     "language.c",
            "messageobj.c", "sprtf.c",
        },
        .flags = &.{
            "-Wall",
            "-Wno-overloaded-virtual",
        },
    });
    return tidy;
}
