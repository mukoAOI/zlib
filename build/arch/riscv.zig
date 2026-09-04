const types = @import("types.zig");

const Macro = types.Macro;
const SourceGroup = types.SourceGroup;
const Config = types.Config;

const riscv_macros = [_]Macro{
    .{ .name = "RISCV_FEATURES", .value = "1" },
    .{ .name = "RISCV_RVV", .value = "1" },
    .{ .name = "RISCV_ZBC", .value = "1" },
};

const gnu_rvv = &[_][]const u8{ "-march=rv64gc_v1p0", "-mabi=lp64d", "-fno-lto" };
const gnu_riscv_zbc = &[_][]const u8{ "-march=rv64gc_zbc", "-mabi=lp64d", "-fno-lto" };

const mcpu_riscv_rvv = "baseline+v";
const mcpu_riscv_zbc = "baseline+zbc";

const riscv_rvv_files = [_][]const u8{
    "arch/riscv/adler32_rvv.c",
    "arch/riscv/chunkset_rvv.c",
    "arch/riscv/compare256_rvv.c",
    "arch/riscv/slide_hash_rvv.c",
};
const riscv_zbc_files = [_][]const u8{"arch/riscv/crc32_zbc.c"};
const riscv_features_file = [_][]const u8{"arch/riscv/riscv_features.c"};

const riscv_groups = [_]SourceGroup{
    .{ .files = &riscv_rvv_files, .flags = gnu_rvv, .mcpu = mcpu_riscv_rvv },
    .{ .files = &riscv_zbc_files, .flags = gnu_riscv_zbc, .mcpu = mcpu_riscv_zbc },
    .{ .files = &riscv_features_file, .flags = gnu_rvv, .mcpu = mcpu_riscv_rvv },
};

pub fn configure() Config {
    return .{
        .macros = &riscv_macros,
        .source_groups = &riscv_groups,
        .extra_sources = &types.cpu_features_file,
    };
}
