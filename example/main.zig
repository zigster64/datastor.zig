const std = @import("std");
const cats = @import("cats.zig");
const dogs = @import("dogs.zig");
const animals = @import("animals.zig");
const forrest = @import("forrest.zig");
const simple = @import("simple.zig");
const custom = @import("custom_id.zig");

pub fn main() !void {
    std.debug.print("Datastor examples\n", .{});

    std.debug.print("================================================\n", .{});
    std.debug.print("SIMPLE table examples\n", .{});
    try simple.createTable();
    try simple.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("SIMPLE table with CUSTOM key examples\n", .{});
    try custom.createTable();
    try custom.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("CATS table examples\n", .{});
    try cats.createTable();
    try cats.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("CATS with TIMESERIES events examples\n", .{});
    try cats.createTimeseries();
    //     try cats.createTimeseriesNoIO(); // for measuring IO performance only

    //     try dogs.createTable();
    //     try dogs.createTimeseries();

    //     try animals.createTable();
    //     try animals.loadTable();

    //     try forrest.createTable();
    //     try forrest.loadTable();
}
