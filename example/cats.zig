const std = @import("std");
const datastor = @import("datastor");

const Cat = struct {
    key: usize = 0,
    breed: []const u8,
    color: []const u8,
    length: u16,
    aggression: f32,

    const Self = @This();

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
pub fn run() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("Cats example - simple 2D data structure\n", .{});

    // create a datastor to store the cats
    var CatDB = datastor.Table(Cat).init(gpa);
    defer CatDB.deinit();

    // manually fill in datastor using our example cats seed data, autoincrementing the ID
    for (cats) |cat| {
        try CatDB.appendAutoIncrement(cat);
    }

    // manually get some cats from the datastore
    for (0..4) |i| {
        if (CatDB.values.get(i + 1)) |cat| {
            std.debug.print("Cat {d} is {s}\n", .{ i, cat });
        } else std.debug.print("No cat found !!\n", .{});
    }

    // Save the CatsDB to disk
    try CatDB.save("cats.db");
}
