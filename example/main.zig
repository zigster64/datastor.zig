const std = @import("std");
const cats = @import("cats.zig");

pub fn main() !void {
    std.debug.print("Datastor examples\n", .{});

    try cats.create_simple_table();
    try cats.load_simple_table();
    try cats.create_timeseries();
    try cats.create_timeseries_no_io();
}
