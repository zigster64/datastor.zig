const std = @import("std");
const cats = @import("cats.zig");
const dogs = @import("dogs.zig");
const animals = @import("animals.zig");
const forrest = @import("forrest.zig");
const simple = @import("simple.zig");

pub fn main() !void {
    std.debug.print("Datastor examples\n", .{});

    try simple.createTable();
    try simple.loadTable();

    try cats.createTable();
    try cats.loadTable();
    try cats.createTimeseries();
    try cats.createTimeseriesNoIO(); // for measuring IO performance only

    try dogs.createTable();
    try dogs.createTimeseries();

    try animals.createTable();
    try animals.loadTable();

    try forrest.createTable();
    try forrest.loadTable();
}
