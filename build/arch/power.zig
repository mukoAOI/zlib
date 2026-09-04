const std = @import("std");

const types = @import("types.zig");

const Macro = types.Macro;
const SourceGroup = types.SourceGroup;
const Config = types.Config;

const power_macros = [_]Macro{
    .{ .name = "PPC_FEATURES", .value = "1" },
    .{ .name = "PPC_VMX", .value = "1" },
    .{ .name = "POWER_FEATURES", .value = "1" },
    .{ .name = "POWER8_VSX", .value = "1" },
    .{ .name = "POWER8_VSX_CRC32", .value = "1" },
    .{ .name = "POWER9", .value = "1" },
};

const power_macros_linux = [_]Macro{
    .{ .name = "PPC_FEATURES", .value = "1" },
    .{ .name = "PPC_VMX", .value = "1" },
    .{ .name = "POWER_FEATURES", .value = "1" },
    .{ .name = "POWER8_VSX", .value = "1" },
    .{ .name = "POWER8_VSX_CRC32", .value = "1" },
    .{ .name = "POWER9", .value = "1" },
    .{ .name = "HAVE_SYS_AUXV_H", .value = "1" },
};

const gnu_power_vmx = &[_][]const u8{"-fno-lto"};
const gnu_power8 = &[_][]const u8{"-fno-lto"};
const gnu_power9 = &[_][]const u8{"-fno-lto"};

const mcpu_power_vmx = "baseline+altivec";
const mcpu_power8 = "pwr8";
const mcpu_power9 = "pwr9";

const power_vmx_files = [_][]const u8{
    "arch/power/adler32_vmx.c",
    "arch/power/slide_hash_vmx.c",
};
const power8_files = [_][]const u8{
    "arch/power/adler32_power8.c",
    "arch/power/chunkset_power8.c",
    "arch/power/slide_hash_power8.c",
    "arch/power/crc32_power8.c",
};
const power9_files = [_][]const u8{"arch/power/compare256_power9.c"};
const power_features_file = [_][]const u8{"arch/power/power_features.c"};

const power_groups = [_]SourceGroup{
    .{ .files = &power_vmx_files, .flags = gnu_power_vmx, .mcpu = mcpu_power_vmx },
    .{ .files = &power8_files, .flags = gnu_power8, .mcpu = mcpu_power8 },
    .{ .files = &power9_files, .flags = gnu_power9, .mcpu = mcpu_power9 },
    .{ .files = &power_features_file },
};

pub fn configure(target: std.Target) Config {
    return .{
        .macros = if (target.os.tag == .linux) &power_macros_linux else &power_macros,
        .source_groups = &power_groups,
        .extra_sources = &types.cpu_features_file,
    };
}
