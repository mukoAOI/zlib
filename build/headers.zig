const std = @import("std");
const Build = std.Build;

const lib = @import("headers_lib.zig");

pub const Options = struct {
    backend: enum { zlib, @"zlib-ng" },
    have_unistd: bool = false,
    symbol_prefix: []const u8 = "",
    zprefix: bool = false,
};

pub fn install(b: *Build, wf: *Build.Step.WriteFile, dep: *Build.Dependency, opts: Options) void {
    const io = b.graph.io;
    const source_root = dep.path("").getPath2(b, &wf.step);

    switch (opts.backend) {
        .@"zlib-ng" => {
            const zconf = lib.generateZlibNgZconf(io, b.allocator, source_root, opts.have_unistd) catch @panic("generate zconf.h failed");
            _ = wf.add("zconf.h", zconf);

            const zlib_h = lib.generateZlibNgFromTemplate(io, b.allocator, source_root, "zlib.h.in", opts.symbol_prefix) catch @panic("generate zlib.h failed");
            _ = wf.add("zlib.h", zlib_h);

            const mangling = lib.generateZlibNgNameMangling(io, b.allocator, source_root, opts.symbol_prefix) catch @panic("generate zlib_name_mangling.h failed");
            _ = wf.add("zlib_name_mangling.h", mangling);

            const gzread_mangle = lib.generateZlibNgFromTemplate(io, b.allocator, source_root, "gzread_mangle.h.in", opts.symbol_prefix) catch @panic("generate gzread_mangle.h failed");
            _ = wf.add("gzread_mangle.h", gzread_mangle);

            for (&[_][]const u8{ "zconf.h.in", "zlib.h.in", "zlib_name_mangling.h.in", "zlib_name_mangling.h.empty", "gzread_mangle.h.in" }) |name| {
                dep.path(name).addStepDependencies(&wf.step);
            }
        },
        .zlib => {
            const zlib_h = lib.generateZlibH(io, b.allocator, source_root) catch @panic("copy zlib.h failed");
            _ = wf.add("zlib.h", zlib_h);

            const zconf = lib.generateZlibZconf(io, b.allocator, source_root, opts.have_unistd, opts.zprefix) catch @panic("generate zconf.h failed");
            _ = wf.add("zconf.h", zconf);

            for (&[_][]const u8{ "zlib.h", "zconf.h" }) |name| {
                dep.path(name).addStepDependencies(&wf.step);
            }
        },
    }
}
