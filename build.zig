const std = @import("std");

pub fn build(b: *std.Build) void {
    //----------------------------------------
    // Setup standard options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_opts = .{ .target = target, .optimize = optimize };
    _ = dep_opts;

    // Define the module that we export
    const datastor_module = b.addModule("datastor", .{
        .root_source_file = .{ .path = "src/datastor.zig" },
    });

    //----------------------------------------
    // Setup the demo app
    const exe = b.addExecutable(.{
        .name = "datastor.zig demo",
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("datastor", datastor_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the demo app");
    run_step.dependOn(&run_cmd.step);

    //----------------------------------------
    // Add tests
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
        .test_runner = "test_runner.zig",
    });
    tests.root_module.addImport("datastor", datastor_module);
    const run_test = b.addRunArtifact(tests);
    run_test.has_side_effects = true;

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
