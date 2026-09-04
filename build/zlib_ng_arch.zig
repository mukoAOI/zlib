const std = @import("std");
const Build = std.Build;

const types = @import("arch/types.zig");
const apply_mod = @import("arch/apply.zig");
const util = @import("arch/util.zig");
const x86 = @import("arch/x86.zig");
const arm = @import("arch/arm.zig");
const power = @import("arch/power.zig");
const riscv = @import("arch/riscv.zig");
const s390 = @import("arch/s390.zig");
const loongarch = @import("arch/loongarch.zig");
const simd_level = @import("simd_level.zig");

pub const Macro = types.Macro;
pub const SourceGroup = types.SourceGroup;
pub const Config = types.Config;
pub const ApplyContext = apply_mod.ApplyContext;

pub const apply = apply_mod.apply;
pub const applyNative = apply_mod.applyNative;
pub const resolveNativeTarget = apply_mod.resolveNativeTarget;

pub fn configure(
    b: *Build,
    target: std.Target,
    runtime_cpu_detection: bool,
    level: simd_level.SimdLevel,
) Config {
    _ = b;
    if (level == .generic or !runtime_cpu_detection) return .empty;

    return switch (util.detectFamily(target.cpu.arch)) {
        .x86 => x86.configure(target, level),
        .arm => arm.configure(target),
        .power => power.configure(target),
        .riscv => riscv.configure(),
        .s390 => s390.configure(target),
        .loongarch => loongarch.configure(),
        .generic => .empty,
    };
}

pub fn configureNative(b: *Build, target: std.Target, level: simd_level.SimdLevel) Config {
    var config = configure(b, target, true, level);
    config.extra_sources = &.{};
    return config;
}
