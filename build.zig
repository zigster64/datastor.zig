const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const datastor_module = b.addModule("datastor", .{
        .source_file = .{ .path = "src/datastor.zig" },
    });

    // setup executable
    const example_exe = b.addExecutable(.{
        .name = "datastor_example",
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    example_exe.addModule("datastor", datastor_module);
    b.installArtifact(example_exe);

    const run_example = b.addRunArtifact(example_exe);
    run_example.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_example.addArgs(args);
    }
    const run_step = b.step("run", "Run the example app");
    run_step.dependOn(&run_example.step);
}
