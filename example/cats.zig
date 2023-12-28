const std = @import("std");
const datastor = @import("datastor");

const Cat = struct {
    key: usize = 0,
    breed: []const u8,
    color: []const u8,
    length: u16,
    aggression: f32,

    const Self = @This();

    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.breed);
        allocator.free(self.color);
    }

    // datastor doesnt need this, but its put here as a util function to print out a Cat
    pub fn format(cat: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for UUID type: '" ++ layout ++ "'.");

        try std.fmt.format(writer, "ID: {d} Breed: {s} Color: {s} Length: {d}, Aggression Factor: {:.2}", cat);
    }
};

// Some seed data to boot up the cats datastore
const cats = [_]Cat{
    .{ .breed = "Siamese", .color = "white", .length = 30, .aggression = 0.7 },
    .{ .breed = "Burmese", .color = "grey", .length = 24, .aggression = 0.6 },
    .{ .breed = "Tabby", .color = "striped", .length = 32, .aggression = 0.5 },
    .{ .breed = "Bengal", .color = "tiger stripes", .length = 40, .aggression = 0.9 },
};

// An example of a datastor on a simple 2D table
pub fn create_simple_table() !void {
    // remove the original data file
    std.os.unlink("db/cats.db") catch {};

    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nCats example - save simple data set to table\n\n", .{});

    // create a datastor to store the cats
    var CatDB = datastor.Table(Cat).init(gpa);
    defer CatDB.deinit();

    // manually fill in datastor using our example cats seed data, autoincrementing the ID
    // deliberately create a new cat on the heap, duplicating all its components
    for (cats) |cat| {
        try CatDB.appendAutoIncrement(Cat{
            .breed = try gpa.dupe(u8, cat.breed),
            .color = try gpa.dupe(u8, cat.color),
            .length = cat.length,
            .aggression = cat.aggression,
        });
    }

    // manually get some cats from the datastore
    for (0..4) |i| {
        if (CatDB.get(i + 1)) |cat| {
            std.debug.print("Cat {d} is {s}\n", .{ i, cat });
        } else std.debug.print("No cat found !!\n", .{});
    }

    // Save the CatsDB to disk
    try CatDB.save("db/cats.db");
}

// An example of loading a datastor from disk
pub fn load_simple_table() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nCats example - load simple data set from table\n\n", .{});

    // create a datastor to store the cats
    var CatDB = datastor.Table(Cat).init(gpa);
    defer CatDB.deinit();

    try CatDB.load("db/cats.db");
    for (CatDB.list.values(), 0..) |cat, i| {
        std.debug.print("Cat {d} is {s}\n", .{ i, cat });
    }

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nCats example - re-load simple data set from table again, freeing original\n\n", .{});

    // calling load again will clear & free the original store and load a fresh new one
    try CatDB.load("db/cats.db");
    for (CatDB.list.values(), 0..) |cat, i| {
        std.debug.print("Cat {d} is {s}\n", .{ i, cat });
    }
}
