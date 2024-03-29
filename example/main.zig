const std = @import("std");
const cats = @import("cats.zig");
const dogs = @import("dogs.zig");
const animals = @import("animals.zig");
const forrest = @import("forrest.zig");
const simple = @import("simple.zig");
const stringkey = @import("string_key.zig");

pub fn main() !void {
    std.debug.print("Datastor examples\n", .{});

    std.debug.print("================================================\n", .{});
    std.debug.print("SIMPLE table examples\n", .{});
    try simple.createTable();
    try simple.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("SIMPLE table with STRING key examples\n", .{});
    try stringkey.createTable();
    try stringkey.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("CATS table examples\n", .{});
    try cats.createTable();
    try cats.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("CATS with TIMESERIES events examples\n", .{});
    try cats.createTimeseries();

    std.debug.print("================================================\n", .{});
    std.debug.print("DOGS with TIMESERIES events examples\n", .{});
    try dogs.createTable();
    try dogs.createTimeseries();

    std.debug.print("================================================\n", .{});
    std.debug.print("ANIMALS union type examples\n", .{});
    try animals.createTable();
    try animals.loadTable();

    std.debug.print("================================================\n", .{});
    std.debug.print("FORREST tree of union type examples\n", .{});
    try forrest.createTable();
    try forrest.loadTable();
}
