const std = @import("std");
const pkg = @import("build/package.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = pkg.Options.fromBuild(b);

    const raw_backend = b.option([]const u8, "backend", "Zlib backend: zlib or zlib-ng") orelse "zlib";
    const backend = pkg.Backend.parse(raw_backend) orelse std.debug.panic(
        "invalid -Dbackend value '{s}', expected 'zlib' or 'zlib-ng'",
        .{raw_backend},
    );

    // Only fetch the dependency for the selected backend; the other one stays
    // unfetched (Zig fetches build.zig.zon dependencies lazily).
    const dep = switch (backend) {
        .zlib => b.dependency("zlib", .{
            .target = target,
            .optimize = optimize,
        }),
        .@"zlib-ng" => b.dependency("zlib_ng", .{
            .target = target,
            .optimize = optimize,
        }),
    };

    const configured = pkg.configure(b, target, optimize, backend, options, dep);

    const install = b.addInstallArtifact(configured.lib, .{});
    b.getInstallStep().dependOn(&install.step);

    const smoke = b.addExecutable(.{
        .name = "zlib_smoke",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    smoke.root_module.addCSourceFile(.{
        .file = b.path("test/smoke.c"),
        .flags = &.{},
    });
    smoke.root_module.linkLibrary(configured.lib);
    smoke.root_module.addIncludePath(configured.include);

    const smoke_run = b.addRunArtifact(smoke);
    const test_step = b.step("test", "Run compress/gzFile smoke tests");
    test_step.dependOn(&smoke_run.step);
}
