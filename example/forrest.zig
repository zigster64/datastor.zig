const std = @import("std");
const datastor = @import("datastor");

const Allocator = std.mem.Allocator;

const ForrestDB = datastor.Tree(Forrest);

////////////////////////////////////////////////////////////////////////////////
// 3 types of things we can find in the forrest

const Tree = struct {
    x: u8,
    y: u8,
    height: u8,
};

const Creature = struct {
    const Self = @This();
    x: u8,
    y: u8,
    name: []const u8,
    weight: u8,

    // needs a free() function because it has a slice that gets allocated
    pub fn free(self: Self, allocator: Allocator) void {
        allocator.free(self.name);
    }

    pub fn format(self: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for Creature type: '" ++ layout ++ "'.");

        try std.fmt.format(writer, ".x = {d}, .y = {d}, .name = {s}, .weight = {d}", self);
    }
};

const Rock = struct {
    x: u8,
    y: u8,
    width: u8,
};

////////////////////////////////////////////////////////////////////////////////
// ForrestInhabitants is one of these things
const ForrestInhabitantType = enum { tree, creature, rock };

const Forrest = union(ForrestInhabitantType) {
    const Self = @This();
    tree: Tree,
    creature: Creature,
    rock: Rock,

    pub fn free(self: Self, allocator: Allocator) void {
        switch (self) {
            // only creatures need to be freed
            .creature => |creature| creature.free(allocator),
            else => {},
        }
    }
};

pub fn createTable() !void {
    std.os.unlink("db/forrest.db") catch {};

    const gpa = std.heap.page_allocator;

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nForrest (Tree of Union type) create data example\n\n", .{});

    // create a datastor to store the whole forrest
    var forrestDB = try ForrestDB.init(gpa, "db/forrest.db");
    defer forrestDB.deinit();

    // define a complicated forrest with a few levels of detail
    const root_id = try forrestDB.appendNode(0, .{ .tree = .{ .x = 10, .y = 10, .height = 10 } });
    {
        const pine_tree = try forrestDB.appendNode(root_id, .{ .tree = .{ .x = 15, .y = 12, .height = 8 } });
        {
            _ = try forrestDB.appendNode(pine_tree, .{ .creature = .{
                .x = 15,
                .y = 12,
                .name = try gpa.dupe(u8, "Squirrel"),
                .weight = 3,
            } });
            _ = try forrestDB.appendNode(pine_tree, .{ .rock = .{ .x = 15, .y = 12, .width = 2 } });
        }
        const gum_tree = try forrestDB.appendNode(root_id, .{ .tree = .{ .x = 8, .y = 12, .height = 6 } });
        {
            _ = try forrestDB.appendNode(gum_tree, .{ .creature = .{
                .x = 8,
                .y = 12,
                .name = try gpa.dupe(u8, "Koala"),
                .weight = 10,
            } });
            _ = try forrestDB.appendNode(gum_tree, .{ .creature = .{
                .x = 8,
                .y = 12,
                .name = try gpa.dupe(u8, "Kangaroo"),
                .weight = 20,
            } });
        }
        const weed = try forrestDB.appendNode(root_id, .{ .tree = .{ .x = 5, .y = 5, .height = 2 } });
        {
            const moss_rock = try forrestDB.appendNode(weed, .{ .rock = .{ .x = 5, .y = 6, .width = 2 } });
            {
                _ = try forrestDB.appendNode(moss_rock, .{ .creature = .{
                    .x = 5,
                    .y = 6,
                    .name = try gpa.dupe(u8, "Ant"),
                    .weight = 1,
                } });
                _ = try forrestDB.appendNode(moss_rock, .{ .creature = .{
                    .x = 5,
                    .y = 6,
                    .name = try gpa.dupe(u8, "Wasp"),
                    .weight = 1,
                } });
            }
        }
    }

    try forrestDB.save();
}

pub fn loadTable() !void {
    const gpa = std.heap.page_allocator;

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nForrest (Tree of Union type) load example\n\n", .{});

    var forrestDB = try ForrestDB.init(gpa, "db/forrest.db");
    defer forrestDB.deinit();

    try forrestDB.load();
    std.debug.print("Flat display for the contents of the forrest:\n", .{});
    for (forrestDB.items()) |forrest| {
        std.debug.print(" {any}:\n", .{forrest});
    }

    std.debug.print("\nStructured display for the contents of the forrest:\n\n", .{});
    try printForrestRecursive(forrestDB, 0, 0);
}

fn printForrestRecursive(forrestDB: ForrestDB, parent_id: usize, nesting: usize) !void {
    const children = try forrestDB.getChildren(parent_id);
    defer children.deinit();
    for (children.items) |forrest| {
        for (0..nesting) |_| {
            std.debug.print("    ", .{});
        }
        std.debug.print(" {}:\n", .{forrest});
        try printForrestRecursive(forrestDB, forrest.id, nesting + 1);
    }
}
