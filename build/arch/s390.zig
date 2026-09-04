const std = @import("std");

const types = @import("types.zig");

const Macro = types.Macro;
const SourceGroup = types.SourceGroup;
const Config = types.Config;

const s390_macros = [_]Macro{
    .{ .name = "S390_FEATURES", .value = "1" },
    .{ .name = "S390_VX", .value = "1" },
};

const s390_macros_linux = [_]Macro{
    .{ .name = "S390_FEATURES", .value = "1" },
    .{ .name = "S390_VX", .value = "1" },
    .{ .name = "HAVE_SYS_AUXV_H", .value = "1" },
};

const gnu_s390_vx = &[_][]const u8{ "-fzvector", "-fno-lto" };
const mcpu_s390_vx = "z13";

const s390_vx_files = [_][]const u8{
    "arch/s390/crc32_vx.c",
    "arch/s390/slide_hash_vx.c",
};
const s390_features_file = [_][]const u8{"arch/s390/s390_features.c"};

const s390_groups = [_]SourceGroup{
    .{ .files = &s390_vx_files, .flags = gnu_s390_vx, .mcpu = mcpu_s390_vx },
    .{ .files = &s390_features_file },
};

pub fn configure(target: std.Target) Config {
    return .{
        .macros = if (target.os.tag == .linux) &s390_macros_linux else &s390_macros,
        .source_groups = &s390_groups,
        .extra_sources = &types.cpu_features_file,
    };
}
