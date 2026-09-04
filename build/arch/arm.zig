const std = @import("std");

const types = @import("types.zig");
const util = @import("util.zig");

const Macro = types.Macro;
const SourceGroup = types.SourceGroup;
const Config = types.Config;

const arm_base_macros = [_]Macro{
    .{ .name = "ARM_FEATURES", .value = "1" },
    .{ .name = "ARM_NEON", .value = "1" },
    .{ .name = "ARM_NEON_HASLD4", .value = "1" },
    .{ .name = "ARM_CRC32", .value = "1" },
    .{ .name = "ARM_CRC32_INTRIN", .value = "1" },
    .{ .name = "HAVE_ARM_ACLE_H", .value = "1" },
};

const arm_msvc_macros = [_]Macro{
    .{ .name = "__ARM_NEON__", .value = "1" },
};

const arm_32_macros = [_]Macro{
    .{ .name = "ARM_SIMD", .value = "1" },
    .{ .name = "ARM_SIMD_INTRIN", .value = "1" },
};

const arm_64_macros = [_]Macro{
    .{ .name = "ARM_NEON_DOTPROD", .value = "1" },
    .{ .name = "ARM_PMULL_EOR3", .value = "1" },
};

const arm_all_macros_msvc64 = arm_base_macros ++ arm_msvc_macros ++ arm_64_macros;
const arm_all_macros_msvc32 = arm_base_macros ++ arm_msvc_macros ++ arm_32_macros;
const arm_all_macros_gnu64 = arm_base_macros ++ arm_64_macros;
const arm_all_macros_gnu32 = arm_base_macros ++ arm_32_macros;

const gnu_arm_neon64 = &[_][]const u8{ "-march=armv8-a+simd", "-fno-lto" };
const gnu_arm_neon32 = &[_][]const u8{ "-mfpu=neon", "-fno-lto" };
const gnu_armv6 = &[_][]const u8{ "-march=armv6", "-fno-lto" };
const gnu_armv8 = &[_][]const u8{ "-march=armv8-a+crc", "-fno-lto" };
const gnu_arm_dotprod = &[_][]const u8{ "-march=armv8.2-a+dotprod", "-fno-lto" };
const gnu_arm_pmull = &[_][]const u8{ "-march=armv8-a+crypto", "-fno-lto" };

const mcpu_arm_neon_a64 = "baseline+neon";
const mcpu_arm_neon_a32 = "baseline+neon";
const mcpu_armv8_crc = "baseline+crc";
const mcpu_arm_dotprod = "baseline+dotprod";
const mcpu_arm_pmull_eor3 = "baseline+crypto+sha3";

const arm_neon_files = [_][]const u8{
    "arch/arm/adler32_neon.c",
    "arch/arm/chunkset_neon.c",
    "arch/arm/compare256_neon.c",
    "arch/arm/slide_hash_neon.c",
};
const arm_armv6_files = [_][]const u8{"arch/arm/slide_hash_armv6.c"};
const arm_armv8_files = [_][]const u8{"arch/arm/crc32_armv8.c"};
const arm_dotprod_files = [_][]const u8{"arch/arm/adler32_neon_dotprod.c"};
const arm_pmull_files = [_][]const u8{"arch/arm/crc32_armv8_pmull_eor3.c"};
const arm_features_file = [_][]const u8{"arch/arm/arm_features.c"};

const arm_groups_64 = [_]SourceGroup{
    .{ .files = &arm_neon_files, .flags = gnu_arm_neon64, .mcpu = mcpu_arm_neon_a64 },
    .{ .files = &arm_armv8_files, .flags = gnu_armv8, .mcpu = mcpu_armv8_crc },
    .{ .files = &arm_dotprod_files, .flags = gnu_arm_dotprod, .mcpu = mcpu_arm_dotprod },
    .{ .files = &arm_pmull_files, .flags = gnu_arm_pmull, .mcpu = mcpu_arm_pmull_eor3 },
    .{ .files = &arm_features_file },
};

const arm_groups_32 = [_]SourceGroup{
    .{ .files = &arm_neon_files, .flags = gnu_arm_neon32, .mcpu = mcpu_arm_neon_a32 },
    .{ .files = &arm_armv6_files, .flags = gnu_armv6 },
    .{ .files = &arm_armv8_files, .flags = gnu_armv8, .mcpu = mcpu_armv8_crc },
    .{ .files = &arm_features_file },
};

pub fn configure(target: std.Target) Config {
    const compiler = util.detectCompiler(target);
    const bit64 = !util.is32Bit(target);

    return .{
        .macros = switch (compiler) {
            .msvc => if (bit64) &arm_all_macros_msvc64 else &arm_all_macros_msvc32,
            .gnu_like => if (bit64) &arm_all_macros_gnu64 else &arm_all_macros_gnu32,
        },
        .source_groups = if (bit64) &arm_groups_64 else &arm_groups_32,
        .extra_sources = &types.cpu_features_file,
    };
}
