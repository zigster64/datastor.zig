const std = @import("std");
const datastor = @import("datastor");

// Example case where the Key that we use to ID each item is some custom function that returns a custom type

const KeyType = []const u8;
const TableType = datastor.TableWithKey(StringKeyThing, .string);

pub const StringKeyThing = struct {
    x: usize = 0,
    y: usize = 0,

    // The ID for our type is a 16 char string with the count encoded
    // and data from the internals making up part of the key
    pub fn newID(self: StringKeyThing, allocator: std.mem.Allocator, count: usize) !KeyType {
        return try std.fmt.allocPrint(allocator, "ABC-{d}-{d}:{d}", .{ count, self.x, self.y });
    }
};

pub fn createTable() !void {
    // remove the original data file
    std.os.unlink("db/stringkey.db") catch {};

    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nString ID example\n\n", .{});

    // create a datastor to store the things
    var db = try TableType.init(gpa, "db/stringkey.db");
    defer db.deinit();

    const things = [_]StringKeyThing{
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

    for (db.items(), 0..) |thing, i| {
        std.debug.print("Thing {d} has id {s} and value ({d},{d})\n", .{ i, thing.id, thing.value.x, thing.value.y });
    }

    try db.save();
}

pub fn loadTable() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nString Key example - load and reload simple data set from table\n\n", .{});

    var db = try TableType.init(gpa, "db/stringkey.db");
    defer db.deinit();

    try db.load();
    for (db.items(), 0..) |thing, i| {
        std.debug.print("Thing {d} has id {s} and value ({d},{d})\n", .{ i, thing.id, thing.value.x, thing.value.y });
    }

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nReload ... should handle without needing to call free() \n\n", .{});

    try db.load();
    for (db.items(), 0..) |thing, i| {
        std.debug.print("Thing {d} has id {s} and value ({d},{d})\n", .{ i, thing.id, thing.value.x, thing.value.y });
    }

    // try lookup using the custom key
    // TODO - key equality, expect this to fail
    const c1 = db.get("ABC-1-1:2").?;
    const c2 = db.get("ABC-2-3:4").?;
    const c3 = db.get("ABC-3-5:6").?;
    std.debug.print("Got back {s} {} from key ABC-1-1:2\n", .{ c1.id, c1.value });
    std.debug.print("Got back {s} {} from key ABC-2-3:4\n", .{ c2.id, c2.value });
    std.debug.print("Got back {s} {} from key ABC-3-5:6\n", .{ c3.id, c3.value });
}
