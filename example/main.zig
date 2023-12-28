const std = @import("std");
const cats = @import("cats.zig");

pub fn main() !void {
    std.debug.print("Datastor examples\n", .{});

    try cats.run();
}
