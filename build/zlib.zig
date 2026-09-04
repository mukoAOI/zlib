const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

const pkg = @import("package.zig");
const headers = @import("headers.zig");

const core_sources = [_][]const u8{
    "adler32.c",
    "compress.c",
    "crc32.c",
    "deflate.c",
    "infback.c",
    "inffast.c",
    "inflate.c",
    "inftrees.c",
    "trees.c",
    "uncompr.c",
    "zutil.c",
};

const gz_sources = [_][]const u8{
    "gzlib.c",
    "gzread.c",
    "gzwrite.c",
    "gzclose.c",
};

pub fn configure(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: pkg.Options,
    dep: *Build.Dependency,
) struct { lib: *Step.Compile, include: Build.LazyPath } {
    if (options.symbol_prefix.len != 0 and !std.mem.eql(u8, options.symbol_prefix, "z_")) {
        std.debug.panic(
            "stock zlib only supports empty symbol_prefix or 'z_'; for custom prefixes use -Dbackend=zlib-ng",
            .{},
        );
    }

    const use_zprefix = options.symbol_prefix.len != 0;
    const header_files = b.addWriteFiles();
    headers.install(b, header_files, dep, .{
        .backend = .zlib,
        .have_unistd = target.result.os.tag != .windows,
        .zprefix = use_zprefix,
    });
    const install_header_dir = header_files.getDirectory();

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib = b.addLibrary(.{
        .name = "z",
        .linkage = options.linkage,
        .root_module = mod,
    });
    lib.root_module.sanitize_c = .off;

    lib.root_module.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &core_sources,
    });
    lib.root_module.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &gz_sources,
    });
    lib.root_module.addIncludePath(dep.path(""));
    lib.root_module.addIncludePath(install_header_dir);
    if (use_zprefix) {
        lib.root_module.addCMacro("Z_PREFIX", "1");
    }

    if (target.result.os.tag == .windows) {
        lib.root_module.addCMacro("WIN32", "1");
    } else {
        // Quoted `#include "zconf.h"` in the sources resolves to the pristine
        // zconf.h in the dependency source root, shadowing the patched one in
        // install_header_dir. The `#ifdef HAVE_UNISTD_H` gate must therefore
        // be satisfied via a command-line macro, not the patched header.
        lib.root_module.addCMacro("HAVE_UNISTD_H", "1");
    }

    lib.installHeader(install_header_dir.path(b, "zlib.h"), "zlib.h");
    lib.installHeader(install_header_dir.path(b, "zconf.h"), "zconf.h");

    return .{
        .lib = lib,
        .include = install_header_dir,
    };
}
