const std = @import("std");
const pkg = @import("build/package.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = pkg.Options.fromBuild(b);

    const raw_backend = b.option([]const u8, "backend", "Zlib backend: zlib or zlib-ng") orelse "zlib-ng";
    const backend = pkg.Backend.parse(raw_backend) orelse std.debug.panic(
        "invalid -Dbackend value '{s}', expected 'zlib' or 'zlib-ng'",
        .{raw_backend},
    );

    // Only the selected backend is fetched (both deps are marked `.lazy` in
    // build.zig.zon). When the dep is not fetched yet, `lazyDependency` returns
    // null and the build runner fetches it, then re-runs build.zig.
    const dep = (switch (backend) {
        .zlib => b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        }),
        .@"zlib-ng" => b.lazyDependency("zlib_ng", .{
            .target = target,
            .optimize = optimize,
        }),
    }) orelse return;

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
