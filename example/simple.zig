const std = @import("std");
const datastor = @import("datastor");

pub const SimpleThing = struct {
    const Self = @This();
    id: usize = 0,
    x: usize = 0,
    y: usize = 0,

    // nothing gets allocated to create an instance of this, so we dont need a free()
};

pub fn createTable() !void {
    // remove the original data file
    std.os.unlink("db/things.db") catch {};

    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nSimple Things example - no allocation per thing\n\n", .{});

    // create a datastor to store the things
    var db = try datastor.Table(SimpleThing).init(gpa, "db/things.db");
    defer db.deinit();

    const things = [_]SimpleThing{
        .{ .x = 1, .y = 2 },
        .{ .x = 3, .y = 4 },
        .{ .x = 5, .y = 6 },
        .{ .x = 7, .y = 8 },
    };
    // we can use thing here, because there is no heap allocated stuff in the thing,
    // and everything is pass by copy
    for (things) |thing| {
        _ = try db.append(thing);
    }

    for (db.values(), 0..) |thing, i| {
        std.debug.print("Thing {d} is ({d},{d})\n", .{ i, thing.x, thing.y });
    }

    try db.save();
}

pub fn loadTable() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nThing example - load and reload simple data set from table\n\n", .{});

    var db = try datastor.Table(SimpleThing).init(gpa, "db/things.db");
    defer db.deinit();

    try db.load();
    for (db.values(), 0..) |thing, i| {
        std.debug.print("Thing {d} is ({d},{d})\n", .{ i, thing.x, thing.y });
    }

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nReload ... should handle without needing to call free() \n\n", .{});

    try db.load();
    for (db.values(), 0..) |thing, i| {
        std.debug.print("Thing {d} is ({d},{d})\n", .{ i, thing.x, thing.y });
    }
}
