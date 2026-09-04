const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

const simd_level = @import("simd_level.zig");
const zlib_backend = @import("zlib.zig");
const zlib_ng_backend = @import("zlib_ng.zig");

pub const SimdLevel = simd_level.SimdLevel;

pub const Backend = enum {
    zlib,
    @"zlib-ng",

    pub fn parse(name: []const u8) ?Backend {
        if (std.mem.eql(u8, name, "zlib")) return .zlib;
        if (std.mem.eql(u8, name, "zlib-ng")) return .@"zlib-ng";
        return null;
    }

    pub fn label(self: Backend) []const u8 {
        return switch (self) {
            .zlib => "zlib 1.3.1",
            .@"zlib-ng" => "zlib-ng 2.3.90 (develop 1239e88, compat)",
        };
    }
};

pub const Options = struct {
    linkage: std.builtin.LinkMode = .static,
    symbol_prefix: []const u8 = "",
    /// Compile multiple SIMD tiers and pick the best at runtime (zlib-ng).
    runtime_cpu_detection: bool = true,
    /// Bind SIMD to the build host ISA (`-mcpu=native`), no runtime dispatch.
    /// Smaller than full dispatch; requires building for the native target.
    native_instructions: bool = false,
    simd_level: SimdLevel = .max,
    /// Lower memory footprint (zlib-ng WITH_REDUCED_MEM).
    reduced_mem: bool = false,
    /// Strict inflate distance checking (zlib-ng WITH_INFLATE_STRICT).
    inflate_strict: bool = false,

    pub fn fromBuild(b: *Build) Options {
        const raw_linkage = b.option([]const u8, "linkage", "Library linkage: static or dynamic") orelse "static";
        const linkage: std.builtin.LinkMode = blk: {
            if (std.mem.eql(u8, raw_linkage, "static")) break :blk .static;
            if (std.mem.eql(u8, raw_linkage, "dynamic")) break :blk .dynamic;
            std.debug.panic("invalid -Dlinkage value '{s}', expected 'static' or 'dynamic'", .{raw_linkage});
        };

        const raw_simd = b.option([]const u8, "simd_level", "Max x86 SIMD tier: generic, sse2, avx2, avx512, max") orelse "max";
        const simd_level_opt = SimdLevel.parse(raw_simd) orelse std.debug.panic(
            "invalid -Dsimd_level value '{s}', expected generic|sse2|avx2|avx512|max",
            .{raw_simd},
        );

        const native_instructions = b.option(
            bool,
            "native_instructions",
            "Compile zlib-ng SIMD for host CPU (-mcpu=native), no runtime dispatch",
        ) orelse false;

        const runtime_cpu_detection = b.option(
            bool,
            "runtime_cpu_detection",
            "Enable runtime CPU feature detection (zlib-ng)",
        ) orelse true;

        if (native_instructions and runtime_cpu_detection) {
            std.log.info("native_instructions disables runtime_cpu_detection", .{});
        }
        if (native_instructions and simd_level_opt == .generic) {
            std.debug.panic(
                "native_instructions requires a non-generic simd_level; use -Druntime_cpu_detection=false for generic-only builds",
                .{},
            );
        }

        return .{
            .linkage = linkage,
            .symbol_prefix = b.option([]const u8, "symbol_prefix", "Prefix for exported symbols (e.g. z_ or mylib_)") orelse "",
            .runtime_cpu_detection = if (native_instructions) false else runtime_cpu_detection,
            .native_instructions = native_instructions,
            .simd_level = simd_level_opt,
            .reduced_mem = b.option(bool, "reduced_mem", "Reduce zlib-ng memory usage (WITH_REDUCED_MEM)") orelse false,
            .inflate_strict = b.option(bool, "inflate_strict", "Strict inflate distance checks (WITH_INFLATE_STRICT)") orelse false,
        };
    }
};

pub const Package = struct {
    lib: *Step.Compile,
    include: Build.LazyPath,
};

pub fn configure(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    backend: Backend,
    options: Options,
    dep: *Build.Dependency,
) Package {
    return switch (backend) {
        .zlib => blk: {
            const configured = zlib_backend.configure(b, target, optimize, options, dep);
            break :blk .{
                .lib = configured.lib,
                .include = configured.include,
            };
        },
        .@"zlib-ng" => blk: {
            const configured = zlib_ng_backend.configure(b, target, optimize, options, dep);
            break :blk .{
                .lib = configured.lib,
                .include = configured.include,
            };
        },
    };
}
