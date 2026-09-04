const types = @import("types.zig");

const Macro = types.Macro;
const SourceGroup = types.SourceGroup;
const Config = types.Config;

const loongarch_macros = [_]Macro{
    .{ .name = "LOONGARCH_FEATURES", .value = "1" },
    .{ .name = "LOONGARCH_CRC", .value = "1" },
    .{ .name = "LOONGARCH_LSX", .value = "1" },
};

const gnu_lsx = &[_][]const u8{ "-mlsx", "-fno-lto" };
const gnu_loongarch_crc = &[_][]const u8{"-fno-lto"};
const mcpu_loongarch_lsx = "baseline+lsx";

const loongarch_crc_files = [_][]const u8{"arch/loongarch/crc32_la.c"};
const loongarch_lsx_files = [_][]const u8{
    "arch/loongarch/adler32_lsx.c",
    "arch/loongarch/chunkset_lsx.c",
    "arch/loongarch/compare256_lsx.c",
    "arch/loongarch/slide_hash_lsx.c",
};
const loongarch_features_file = [_][]const u8{"arch/loongarch/loongarch_features.c"};

const loongarch_groups = [_]SourceGroup{
    .{ .files = &loongarch_crc_files, .flags = gnu_loongarch_crc },
    .{ .files = &loongarch_lsx_files, .flags = gnu_lsx, .mcpu = mcpu_loongarch_lsx },
    .{ .files = &loongarch_features_file },
};

pub fn configure() Config {
    return .{
        .macros = &loongarch_macros,
        .source_groups = &loongarch_groups,
        .extra_sources = &types.cpu_features_file,
    };
}
