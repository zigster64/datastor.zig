const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const datastor_module = b.addModule("datastor", .{
        .source_file = .{ .path = "src/datastor.zig" },
    });

    // setup executable
    const exe = b.addExecutable(.{
        .name = "datastor.zig demo",
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("datastor", datastor_module);
    b.installArtifact(exe);
}
