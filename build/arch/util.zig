const std = @import("std");
const Build = std.Build;

const types = @import("types.zig");

pub const Family = enum {
    x86,
    arm,
    power,
    riscv,
    s390,
    loongarch,
    generic,
};

pub const Compiler = enum {
    msvc,
    gnu_like,
};

pub fn detectFamily(arch: std.Target.Cpu.Arch) Family {
    return switch (arch) {
        .x86, .x86_64 => .x86,
        .arm, .armeb, .thumb, .thumbeb, .aarch64, .aarch64_be => .arm,
        .powerpc, .powerpc64, .powerpc64le => .power,
        .riscv32, .riscv64 => .riscv,
        .s390x => .s390,
        .loongarch32, .loongarch64 => .loongarch,
        else => .generic,
    };
}

pub fn detectCompiler(target: std.Target) Compiler {
    return if (target.abi == .msvc) .msvc else .gnu_like;
}

pub fn is32Bit(target: std.Target) bool {
    return target.ptrBitWidth() == 32;
}

pub fn objectName(b: *Build, source: []const u8) []const u8 {
    var hash: u64 = 14695981039346656037;
    for (source) |c| {
        hash ^= c;
        hash *%= 1099511628211;
    }
    return b.fmt("zng_{x}", .{hash});
}

pub fn isArchFeaturesFile(path: []const u8) bool {
    return std.mem.endsWith(u8, path, "_features.c");
}

pub fn nativeGroupSupported(native: std.Target, group: types.SourceGroup) bool {
    if (group.native_x86_features.len == 0) return true;
    if (detectFamily(native.cpu.arch) != .x86) return true;
    for (group.native_x86_features) |feature| {
        if (!native.cpu.features.isEnabled(@intFromEnum(feature))) return false;
    }
    return true;
}
