const std = @import("std");

const types = @import("types.zig");
const util = @import("util.zig");
const simd_level = @import("../simd_level.zig");

const Macro = types.Macro;
const SourceGroup = types.SourceGroup;
const Config = types.Config;

const x86_macros_base = [_]Macro{
    .{ .name = "X86_FEATURES", .value = "1" },
    .{ .name = "X86_SSE2", .value = "1" },
    .{ .name = "X86_SSSE3", .value = "1" },
    .{ .name = "X86_SSE41", .value = "1" },
    .{ .name = "X86_SSE42", .value = "1" },
    .{ .name = "X86_PCLMULQDQ_CRC", .value = "1" },
};

const x86_macros_avx2 = [_]Macro{
    .{ .name = "X86_AVX2", .value = "1" },
    .{ .name = "X86_AVX2VNNI", .value = "1" },
    .{ .name = "X86_VPCLMULQDQ_AVX2", .value = "1" },
};

const x86_macros_avx512 = [_]Macro{
    .{ .name = "X86_AVX512", .value = "1" },
    .{ .name = "X86_AVX512VNNI", .value = "1" },
    .{ .name = "X86_VPCLMULQDQ_AVX512", .value = "1" },
};

const x86_macros_through_avx2 = x86_macros_base ++ x86_macros_avx2;
const x86_macros_max = x86_macros_through_avx2 ++ x86_macros_avx512;

const x86_cpuid_ms = [_]Macro{
    .{ .name = "HAVE_CPUID_MS", .value = "1" },
    .{ .name = "__SSE__", .value = "1" },
    .{ .name = "__SSE2__", .value = "1" },
};

const x86_cpuid_gnu = [_]Macro{
    .{ .name = "HAVE_CPUID_GNU", .value = "1" },
    .{ .name = "X86_HAVE_XSAVE_INTRIN", .value = "1" },
};

const x86_all_macros_msvc_sse2 = x86_macros_base ++ x86_cpuid_ms;
const x86_all_macros_gnu_sse2 = x86_macros_base ++ x86_cpuid_gnu;
const x86_all_macros_msvc_avx2 = x86_macros_through_avx2 ++ x86_cpuid_ms;
const x86_all_macros_gnu_avx2 = x86_macros_through_avx2 ++ x86_cpuid_gnu;
const x86_all_macros_msvc_avx512 = x86_macros_max ++ x86_cpuid_ms;
const x86_all_macros_gnu_avx512 = x86_macros_max ++ x86_cpuid_gnu;

const gnu_sse2 = &[_][]const u8{ "-msse2", "-fno-lto" };
const gnu_ssse3 = &[_][]const u8{ "-mssse3", "-fno-lto" };
const gnu_sse41 = &[_][]const u8{ "-msse4.1", "-fno-lto" };
const gnu_sse42 = &[_][]const u8{ "-msse4.2", "-fno-lto" };
const gnu_pclmul = &[_][]const u8{ "-msse4.2", "-mpclmul", "-fno-lto" };
const gnu_avx2 = &[_][]const u8{ "-mavx2", "-mbmi", "-mbmi2", "-fno-lto" };
const gnu_avx2_vnni = &[_][]const u8{ "-mavx2", "-mavxvnni", "-mbmi", "-mbmi2", "-fno-lto" };
const gnu_avx512 = &[_][]const u8{ "-mavx512f", "-mavx512dq", "-mavx512bw", "-mavx512vl", "-mbmi", "-mbmi2", "-fno-lto" };
const gnu_avx512_vnni = &[_][]const u8{ "-mavx512f", "-mavx512dq", "-mavx512bw", "-mavx512vl", "-mavx512vnni", "-mbmi", "-mbmi2", "-fno-lto" };
const gnu_vpclmul_avx2 = &[_][]const u8{ "-mpclmul", "-mvpclmulqdq", "-mavx2", "-mbmi", "-mbmi2", "-fno-lto" };
const gnu_vpclmul_avx512 = &[_][]const u8{ "-mpclmul", "-mvpclmulqdq", "-mavx512f", "-mavx512dq", "-mavx512bw", "-mavx512vl", "-mbmi", "-mbmi2", "-fno-lto" };
const gnu_xsave = &[_][]const u8{"-mxsave"};

const mcpu_sse2 = "baseline+sse2";
const mcpu_ssse3 = "baseline+ssse3";
const mcpu_sse41 = "baseline+sse4_1";
const mcpu_sse42 = "baseline+sse4_2";
const mcpu_pclmul = "baseline+sse4_2+pclmul";
const mcpu_avx2 = "baseline+avx2+bmi+bmi2";
const mcpu_avx2_vnni = "baseline+avx2+avxvnni+bmi+bmi2";
const mcpu_avx512 = "baseline+avx512f+avx512dq+avx512bw+avx512vl+bmi+bmi2";
const mcpu_avx512_vnni = "baseline+avx512f+avx512dq+avx512bw+avx512vl+avx512vnni+bmi+bmi2";
const mcpu_vpclmul_avx2 = "baseline+avx2+bmi+bmi2+pclmul+vpclmulqdq";
const mcpu_vpclmul_avx512 = "baseline+avx512f+avx512dq+avx512bw+avx512vl+bmi+bmi2+pclmul+vpclmulqdq";
const mcpu_xsave = "baseline+xsave";

const x86_sse2_files = [_][]const u8{
    "arch/x86/chunkset_sse2.c",
    "arch/x86/compare256_sse2.c",
    "arch/x86/crc32_chorba_sse2.c",
    "arch/x86/slide_hash_sse2.c",
};
const x86_ssse3_files = [_][]const u8{
    "arch/x86/adler32_ssse3.c",
    "arch/x86/chunkset_ssse3.c",
};
const x86_sse41_files = [_][]const u8{"arch/x86/crc32_chorba_sse41.c"};
const x86_sse42_files = [_][]const u8{"arch/x86/adler32_sse42.c"};
const x86_pclmul_files = [_][]const u8{"arch/x86/crc32_pclmulqdq.c"};
const x86_avx2_files = [_][]const u8{
    "arch/x86/slide_hash_avx2.c",
    "arch/x86/chunkset_avx2.c",
    "arch/x86/compare256_avx2.c",
    "arch/x86/adler32_avx2.c",
};
const x86_avx2_vnni_files = [_][]const u8{"arch/x86/adler32_avx2_vnni.c"};
const x86_avx512_files = [_][]const u8{
    "arch/x86/adler32_avx512.c",
    "arch/x86/chunkset_avx512.c",
    "arch/x86/compare256_avx512.c",
};
const x86_avx512_vnni_files = [_][]const u8{"arch/x86/adler32_avx512_vnni.c"};
const x86_vpclmul_avx2_files = [_][]const u8{"arch/x86/crc32_vpclmulqdq_avx2.c"};
const x86_vpclmul_avx512_files = [_][]const u8{"arch/x86/crc32_vpclmulqdq_avx512.c"};
const x86_features_file = [_][]const u8{"arch/x86/x86_features.c"};

const x86_groups_base = [_]SourceGroup{
    .{ .files = &x86_sse2_files, .flags = gnu_sse2, .mcpu = mcpu_sse2 },
    .{ .files = &x86_ssse3_files, .flags = gnu_ssse3, .mcpu = mcpu_ssse3 },
    .{ .files = &x86_sse41_files, .flags = gnu_sse41, .mcpu = mcpu_sse41 },
    .{ .files = &x86_sse42_files, .flags = gnu_sse42, .mcpu = mcpu_sse42 },
    .{ .files = &x86_pclmul_files, .flags = gnu_pclmul, .mcpu = mcpu_pclmul },
    .{ .files = &x86_features_file, .flags = gnu_xsave, .mcpu = mcpu_xsave },
};

const x86_req_avx512 = [_]std.Target.x86.Feature{ .avx512f, .avx512dq, .avx512bw, .avx512vl };

const x86_groups_avx2 = [_]SourceGroup{
    .{ .files = &x86_avx2_files, .flags = gnu_avx2, .mcpu = mcpu_avx2, .native_x86_features = &.{.avx2} },
    .{ .files = &x86_avx2_vnni_files, .flags = gnu_avx2_vnni, .mcpu = mcpu_avx2_vnni, .native_x86_features = &.{ .avx2, .avxvnni } },
    .{ .files = &x86_vpclmul_avx2_files, .flags = gnu_vpclmul_avx2, .mcpu = mcpu_vpclmul_avx2, .native_x86_features = &.{ .avx2, .vpclmulqdq } },
};

const x86_groups_avx512 = [_]SourceGroup{
    .{ .files = &x86_avx512_files, .flags = gnu_avx512, .mcpu = mcpu_avx512, .native_x86_features = &x86_req_avx512 },
    .{ .files = &x86_avx512_vnni_files, .flags = gnu_avx512_vnni, .mcpu = mcpu_avx512_vnni, .native_x86_features = &.{ .avx512f, .avx512dq, .avx512bw, .avx512vl, .avx512vnni } },
    .{ .files = &x86_vpclmul_avx512_files, .flags = gnu_vpclmul_avx512, .mcpu = mcpu_vpclmul_avx512, .native_x86_features = &.{ .avx512f, .avx512dq, .avx512bw, .avx512vl, .vpclmulqdq } },
};

const x86_groups_through_avx2 = x86_groups_base ++ x86_groups_avx2;
const x86_groups_max = x86_groups_through_avx2 ++ x86_groups_avx512;

pub fn configure(target: std.Target, level: simd_level.SimdLevel) Config {
    const compiler = util.detectCompiler(target);
    const cpuid_msvc = switch (level) {
        .generic => unreachable,
        .sse2 => &x86_all_macros_msvc_sse2,
        .avx2 => &x86_all_macros_msvc_avx2,
        .avx512, .max => &x86_all_macros_msvc_avx512,
    };
    const cpuid_gnu = switch (level) {
        .generic => unreachable,
        .sse2 => &x86_all_macros_gnu_sse2,
        .avx2 => &x86_all_macros_gnu_avx2,
        .avx512, .max => &x86_all_macros_gnu_avx512,
    };
    const groups = switch (level) {
        .generic => unreachable,
        .sse2 => &x86_groups_base,
        .avx2 => &x86_groups_through_avx2,
        .avx512, .max => &x86_groups_max,
    };

    return .{
        .macros = switch (compiler) {
            .msvc => cpuid_msvc,
            .gnu_like => cpuid_gnu,
        },
        .source_groups = groups,
        .extra_sources = &types.cpu_features_file,
    };
}
