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
            @compileError("Unsupported format specifier for Cat type: '" ++ layout ++ "'.");

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
    var catDB = try datastor.Table(Cat).init(gpa, "db/cats.db");
    defer catDB.deinit();

    // manually fill in datastor using our example cats seed data, autoincrementing the ID
    // deliberately create a new cat on the heap, duplicating all its components
    for (cats) |cat| {
        try catDB.append(Cat{
            .breed = try gpa.dupe(u8, cat.breed),
            .color = try gpa.dupe(u8, cat.color),
            .length = cat.length,
            .aggression = cat.aggression,
        });
    }

    // manually get some cats from the datastore
    for (0..4) |i| {
        if (catDB.get(i + 1)) |cat| {
            std.debug.print("Cat {d} is {s}\n", .{ i, cat });
        } else std.debug.print("No cat found !!\n", .{});
    }

    // Save the CatsDB to disk
    try catDB.save();
}

// An example of loading a datastor from disk
pub fn load_simple_table() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nCats example - load simple data set from table\n\n", .{});

    // create a datastor to store the cats
    var catDB = try datastor.Table(Cat).init(gpa, "db/cats.db");
    defer catDB.deinit();

    try catDB.load();
    for (catDB.values(), 0..) |cat, i| {
        std.debug.print("Cat {d} is {s}\n", .{ i, cat });
    }

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nCats example - re-load simple data set from table again, freeing original\n\n", .{});

    // calling load again will clear & free the original store and load a fresh new one
    try catDB.load();
    for (catDB.values(), 0..) |cat, i| {
        std.debug.print("Cat {d} is {s}\n", .{ i, cat });
    }
}

// A timeseries record of events that are associated with a cat
const CatEvent = struct {
    parent_key: usize = 0,
    timestamp: i64,
    x: u16,
    y: u16,
    attacks: bool,
    kills: bool,
    sleep: bool,
    description: []const u8,

    const Self = @This();

    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }

    // datastor doesnt need this, but its put here as a util function to print out a Cat
    pub fn format(self: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for CatEvent type: '" ++ layout ++ "'.");

        try std.fmt.format(
            writer,
            "ParentID: {d} Timestamp: {d} At {d},{d}  Attacks: {any} Kills {any} Sleeps {any} Comment: {s}\n",
            .{
                self.parent_key,
                self.timestamp,
                self.x,
                self.y,
                self.attacks,
                self.kills,
                self.sleep,
                self.description,
            },
        );
    }
};

// Some seed data to boot up the cat events timeseries data
const cat_events = [_]CatEvent{
    .{ .parent_key = 1, .timestamp = 1, .x = 10, .y = 10, .attacks = false, .kills = false, .sleep = true, .description = "Starting Location" },
    .{ .parent_key = 2, .timestamp = 1, .x = 20, .y = 10, .attacks = false, .kills = false, .sleep = true, .description = "Burmese Starting Location" },
    .{ .parent_key = 3, .timestamp = 1, .x = 10, .y = 20, .attacks = false, .kills = false, .sleep = true, .description = "Tabby Starting Location" },
    .{ .parent_key = 4, .timestamp = 1, .x = 20, .y = 20, .attacks = false, .kills = false, .sleep = true, .description = "Bengal Starting Location" },
    .{ .parent_key = 1, .timestamp = 10, .x = 10, .y = 10, .attacks = false, .kills = false, .sleep = false, .description = "Siamese Awakes" },
    .{ .parent_key = 1, .timestamp = 20, .x = 20, .y = 10, .attacks = true, .kills = false, .sleep = false, .description = "Siamese attacks Burmese" },
    .{ .parent_key = 2, .timestamp = 21, .x = 20, .y = 10, .attacks = false, .kills = false, .sleep = false, .description = "Burmese Awakes" },
    .{ .parent_key = 3, .timestamp = 24, .x = 10, .y = 20, .attacks = false, .kills = false, .sleep = false, .description = "Tabby Awakes" },
    .{ .parent_key = 2, .timestamp = 25, .x = 20, .y = 10, .attacks = true, .kills = false, .sleep = false, .description = "Burmese Retaliates against Siamese" },
    .{ .parent_key = 4, .timestamp = 30, .x = 20, .y = 20, .attacks = false, .kills = false, .sleep = false, .description = "Bengal Awakes from all the commotion" },
    .{ .parent_key = 3, .timestamp = 35, .x = 10, .y = 20, .attacks = false, .kills = false, .sleep = true, .description = "Tabby goes back to sleep" },
    .{ .parent_key = 4, .timestamp = 40, .x = 20, .y = 10, .attacks = true, .kills = false, .sleep = false, .description = "Bengal Attacks Burmese and Siamese" },
};

pub fn create_timeseries() !void {
    // start with no timeseries data on file
    std.os.unlink("db/cats.events") catch {};

    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nCats example - Cats TableTimeseries boot initial data\n\n", .{});

    var catDB = try datastor.TableWithTimeseries(Cat, CatEvent).init(gpa, "db/cats.db", "db/cats.events");
    defer catDB.deinit();

    // load both the base table, and all the events for all cats
    try catDB.load();

    std.debug.print("\nExpecting that the timeseries data for all cats should be empty here, found = {d}\n", .{catDB.eventCount()});

    // manually setup the timeseries events to setup the events table on disk
    for (cat_events) |event| {
        try catDB.addEvent(event);
    }

    // print out all the events in timestamp order
    std.debug.print("After all events loaded, expect a list of events in timestamp order:\n", .{});
    for (catDB.getAllEvents()) |event| {
        std.debug.print("{s}", .{event});
    }

    // now print out Cats in the datastor, along with an audit trail of events for each cat
    std.debug.print("\nAll cats with audit trail:\n", .{});
    for (catDB.values()) |cat| {
        std.debug.print("Cat {s}\n", .{cat});
        const events = try catDB.getEventsFor(cat.key);
        for (events.items) |event| {
            std.debug.print("  - At {d}: {s} -> moves to ({d},{d}) status: (Asleep:{any}, Attacking:{any})\n", .{ event.timestamp, event.description, event.x, event.y, event.sleep, event.attacks });
        }
        defer events.deinit();
    }

    // iterate through 3 timestamps and show the state of all cats at the given timestamp
    for (0..4) |i| {
        const t = i * 10 + 1;
        std.debug.print("\nState of all cats at Timestamp {d}\n", .{t});
    }
}
