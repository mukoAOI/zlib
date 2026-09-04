const std = @import("std");

pub const SimdLevel = enum {
    generic,
    sse2,
    avx2,
    avx512,
    max,

    pub fn parse(name: []const u8) ?SimdLevel {
        if (std.mem.eql(u8, name, "generic")) return .generic;
        if (std.mem.eql(u8, name, "sse2")) return .sse2;
        if (std.mem.eql(u8, name, "avx2")) return .avx2;
        if (std.mem.eql(u8, name, "avx512")) return .avx512;
        if (std.mem.eql(u8, name, "max")) return .max;
        return null;
    }
};
