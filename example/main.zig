const std = @import("std");
const cats = @import("cats.zig");
const dogs = @import("dogs.zig");
const animals = @import("animals.zig");

pub fn main() !void {
    std.debug.print("Datastor examples\n", .{});

    try cats.createSimpleTable();
    try cats.loadSimpleTable();
    try cats.createTimeseries();
    try cats.createTimeseriesNoIO();
    try dogs.createSimpleTable();
    try dogs.createTimeseries();
    try animals.createSimpleTable();
}
