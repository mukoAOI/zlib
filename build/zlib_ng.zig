const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

const pkg = @import("package.zig");
const arch = @import("zlib_ng_arch.zig");
const headers = @import("headers.zig");

const generic_sources = [_][]const u8{
    "arch/generic/adler32_c.c",
    "arch/generic/chunkset_c.c",
    "arch/generic/compare256_c.c",
    "arch/generic/crc32_braid_c.c",
    "arch/generic/crc32_chorba_c.c",
    "arch/generic/slide_hash_c.c",
};

const core_sources = [_][]const u8{
    "adler32.c",
    "compress.c",
    "crc32.c",
    "crc32_braid_comb.c",
    "deflate.c",
    "deflate_fast.c",
    "deflate_huff.c",
    "deflate_medium.c",
    "deflate_quick.c",
    "deflate_rle.c",
    "deflate_slow.c",
    "deflate_stored.c",
    "functable.c",
    "infback.c",
    "inflate.c",
    "inftrees.c",
    "insert_string.c",
    "trees.c",
    "uncompr.c",
    "zutil.c",
};

const gz_sources = [_][]const u8{
    "gzlib.c",
    "gzread.c",
    "gzwrite.c",
};

pub fn configure(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: pkg.Options,
    dep: *Build.Dependency,
) struct { lib: *Step.Compile, include: Build.LazyPath } {
    const header_files = b.addWriteFiles();
    headers.install(b, header_files, dep, .{
        .backend = .@"zlib-ng",
        .have_unistd = target.result.os.tag != .windows,
        .symbol_prefix = options.symbol_prefix,
    });
    const header_dir = header_files.getDirectory();

    const effective_target = if (options.native_instructions)
        arch.resolveNativeTarget(b, target)
    else
        target;

    const mod = b.createModule(.{
        .target = if (options.native_instructions) effective_target else target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib = b.addLibrary(.{
        .name = "z",
        .linkage = options.linkage,
        .root_module = mod,
    });
    lib.root_module.sanitize_c = .off;

    var base_macros_buf: [11]arch.Macro = undefined;
    var base_macros_len: usize = 0;
    base_macros_buf[base_macros_len] = .{ .name = "ZLIB_COMPAT", .value = "1" };
    base_macros_len += 1;
    base_macros_buf[base_macros_len] = .{ .name = "WITH_OPTIM", .value = "1" };
    base_macros_len += 1;
    base_macros_buf[base_macros_len] = .{ .name = "WITH_NEW_STRATEGIES", .value = "1" };
    base_macros_len += 1;
    base_macros_buf[base_macros_len] = .{ .name = "WITH_CRC32_CHORBA", .value = "1" };
    base_macros_len += 1;
    base_macros_buf[base_macros_len] = .{ .name = "WITH_GZFILEOP", .value = "1" };
    base_macros_len += 1;
    if (options.reduced_mem) {
        base_macros_buf[base_macros_len] = .{ .name = "HASH_SIZE", .value = "32768u" };
        base_macros_len += 1;
        base_macros_buf[base_macros_len] = .{ .name = "GZBUFSIZE", .value = "8192" };
        base_macros_len += 1;
        base_macros_buf[base_macros_len] = .{ .name = "NO_LIT_MEM", .value = "1" };
        base_macros_len += 1;
    }
    if (options.inflate_strict) {
        base_macros_buf[base_macros_len] = .{ .name = "INFLATE_STRICT", .value = "1" };
        base_macros_len += 1;
    }
    if (!options.runtime_cpu_detection) {
        base_macros_buf[base_macros_len] = .{ .name = "DISABLE_RUNTIME_CPU_DETECTION", .value = "1" };
        base_macros_len += 1;
    }
    if (target.result.os.tag == .windows) {
        base_macros_buf[base_macros_len] = .{ .name = "WIN32", .value = "1" };
        base_macros_len += 1;
    }
    const base_macros = base_macros_buf[0..base_macros_len];

    for (base_macros) |macro| {
        lib.root_module.addCMacro(macro.name, macro.value);
    }

    lib.root_module.addIncludePath(dep.path(""));
    lib.root_module.addIncludePath(header_dir);
    lib.root_module.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &generic_sources,
    });
    lib.root_module.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &core_sources,
    });
    lib.root_module.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &gz_sources,
    });

    if (options.native_instructions) {
        const arch_config = arch.configureNative(b, target.result, options.simd_level);
        arch.applyNative(.{
            .b = b,
            .lib = lib,
            .dep = dep,
            .target = effective_target,
            .optimize = optimize,
            .header_dir = header_dir,
            .base_macros = base_macros,
        }, arch_config);
    } else {
        const arch_config = arch.configure(b, target.result, options.runtime_cpu_detection, options.simd_level);
        arch.apply(.{
            .b = b,
            .lib = lib,
            .dep = dep,
            .target = target,
            .optimize = optimize,
            .header_dir = header_dir,
            .base_macros = base_macros,
        }, arch_config);
    }

    lib.installHeader(header_dir.path(b, "zlib.h"), "zlib.h");
    lib.installHeader(header_dir.path(b, "zconf.h"), "zconf.h");
    lib.installHeader(header_dir.path(b, "zlib_name_mangling.h"), "zlib_name_mangling.h");

    return .{
        .lib = lib,
        .include = header_dir,
    };
}
