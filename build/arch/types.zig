const std = @import("std");

pub const Macro = struct {
    name: []const u8,
    value: []const u8,
};

pub const SourceGroup = struct {
    files: []const []const u8,
    flags: []const []const u8 = &.{},
    mcpu: ?[]const u8 = null,
    native_x86_features: []const std.Target.x86.Feature = &.{},
};

pub const Config = struct {
    macros: []const Macro = &.{},
    source_groups: []const SourceGroup = &.{},
    extra_sources: []const []const u8 = &.{},

    pub const empty: Config = .{};
};

pub const cpu_features_file = [_][]const u8{"cpu_features.c"};
