const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

const types = @import("types.zig");
const util = @import("util.zig");

pub const ApplyContext = struct {
    b: *Build,
    lib: *Step.Compile,
    dep: *Build.Dependency,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    header_dir: Build.LazyPath,
    base_macros: []const types.Macro = &.{},
};

pub fn apply(ctx: ApplyContext, config: types.Config) void {
    for (config.macros) |macro| {
        ctx.lib.root_module.addCMacro(macro.name, macro.value);
    }

    for (config.source_groups) |group| {
        for (group.files) |file| {
            addArchObject(ctx, config.macros, file, group.flags, group.mcpu);
        }
    }

    if (config.extra_sources.len != 0) {
        ctx.lib.root_module.addCSourceFiles(.{
            .root = ctx.dep.path(""),
            .files = config.extra_sources,
        });
    }
}

pub fn applyNative(ctx: ApplyContext, config: types.Config) void {
    const native = ctx.target.result;

    for (config.macros) |macro| {
        ctx.lib.root_module.addCMacro(macro.name, macro.value);
    }

    for (config.source_groups) |group| {
        if (!util.nativeGroupSupported(native, group)) continue;
        for (group.files) |file| {
            if (util.isArchFeaturesFile(file)) continue;
            addArchObject(ctx, config.macros, file, group.flags, "native");
        }
    }
}

pub fn resolveNativeTarget(b: *Build, target: Build.ResolvedTarget) Build.ResolvedTarget {
    const host = b.graph.host;
    if (target.result.cpu.arch != host.result.cpu.arch or
        target.result.os.tag != host.result.os.tag or
        target.result.abi != host.result.abi)
    {
        const host_triple = host.query.zigTriple(b.allocator) catch @panic("OOM");
        defer b.allocator.free(host_triple);
        const target_triple = target.query.zigTriple(b.allocator) catch @panic("OOM");
        defer b.allocator.free(target_triple);
        std.debug.panic(
            "-Dnative_instructions=true requires the default native target (host {s}, got {s})",
            .{ host_triple, target_triple },
        );
    }

    const triple = target.query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    const query = Build.parseTargetQuery(.{
        .arch_os_abi = triple,
        .cpu_features = "native",
    }) catch @panic("invalid native cpu features");
    return b.resolveTargetQuery(query);
}

fn resolveGroupTarget(b: *Build, base: Build.ResolvedTarget, mcpu: []const u8) Build.ResolvedTarget {
    const triple = base.query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    const query = Build.parseTargetQuery(.{
        .arch_os_abi = triple,
        .cpu_features = mcpu,
    }) catch @panic("invalid simd mcpu");
    return b.resolveTargetQuery(query);
}

fn addArchObject(
    ctx: ApplyContext,
    arch_macros: []const types.Macro,
    source: []const u8,
    flags: []const []const u8,
    mcpu: ?[]const u8,
) void {
    const obj_target = if (mcpu) |cpu|
        resolveGroupTarget(ctx.b, ctx.target, cpu)
    else
        ctx.target;

    const obj = ctx.b.addObject(.{
        .name = util.objectName(ctx.b, source),
        .root_module = ctx.b.createModule(.{
            .target = obj_target,
            .optimize = ctx.optimize,
            .link_libc = true,
        }),
    });
    obj.root_module.sanitize_c = .off;
    obj.root_module.addIncludePath(ctx.dep.path(""));
    obj.root_module.addIncludePath(ctx.header_dir);

    for (ctx.base_macros) |macro| {
        obj.root_module.addCMacro(macro.name, macro.value);
    }
    for (arch_macros) |macro| {
        obj.root_module.addCMacro(macro.name, macro.value);
    }

    obj.root_module.addCSourceFile(.{
        .file = ctx.dep.path(source),
        .flags = flags,
    });
    ctx.lib.root_module.addObject(obj);
}
