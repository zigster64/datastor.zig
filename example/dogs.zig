const std = @import("std");
const datastor = @import("datastor");

pub const Dog = struct {
    breed: []const u8,
    color: []const u8,
    height: u16,
    appetite: f32,

    const Self = @This();

    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.breed);
        allocator.free(self.color);
    }

    // datastor doesnt need this, but its put here as a util function to print out a Dog
    pub fn format(dog: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for Dog type: '" ++ layout ++ "'.");

        try std.fmt.format(writer, "Breed: {s} Color: {s} Height: {d}, Appetite: {:.2}", dog);
    }
};

// Some seed data to boot up the dogs datastore
const dogs = [_]Dog{
    .{ .breed = "Colley", .color = "black and white", .height = 30, .appetite = 0.7 },
    .{ .breed = "Pekinese", .color = "grey", .height = 24, .appetite = 0.3 },
    .{ .breed = "Shepard", .color = "striped", .height = 32, .appetite = 0.8 },
    .{ .breed = "Wolf", .color = "black", .height = 40, .appetite = 1.2 },
};

// An example of a datastor on a simple 2D table
pub fn createTable() !void {
    // remove the original data file
    std.os.unlink("db/dogs.db") catch {};

    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nDogs example - save simple data set to table\n\n", .{});

    // create a datastor to store the dog
    var dogDB = try datastor.Table(Dog).init(gpa, "db/dogs.db");
    defer dogDB.deinit();

    // manually fill in datastor using our example dog seed data, autoincrementing the ID
    // deliberately create a new dog on the heap, duplicating all its components
    for (dogs) |dog| {
        _ = try dogDB.append(.{
            .breed = try gpa.dupe(u8, dog.breed),
            .color = try gpa.dupe(u8, dog.color),
            .height = dog.height,
            .appetite = dog.appetite,
        });
    }

    // manually get some dogs from the datastore
    for (0..4) |i| {
        if (dogDB.get(i + 1)) |dog| {
            std.debug.print("Dog {d} is {s}\n", .{ i, dog });
        } else std.debug.print("No dog found !!\n", .{});
    }

    // Save the dogDB to disk
    try dogDB.save();
}

// A timeseries record of events that are associated with a dog
pub const DogEvent = struct {
    x: u16,
    y: u16,
    running: bool,
    eating: bool,
    sleeping: bool,
    description: []const u8,

    const Self = @This();

    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }

    // datastor doesnt need this, but its put here as a util function to print out a Dog
    pub fn format(self: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for DogEvent type: '" ++ layout ++ "'.");

        try std.fmt.format(
            writer,
            "Location {d},{d}  Running: {any} Eating {any} Sleeping {any} Comment: {s}\n",
            .{
                self.x,
                self.y,
                self.running,
                self.eating,
                self.sleeping,
                self.description,
            },
        );
    }
};

const Event = struct {
    parent_id: usize,
    timestamp: i64,
    value: DogEvent,
};
// Some seed data to boot up the dog events timeseries data
const dog_events = [_]Event{
    .{ .parent_id = 1, .timestamp = 1, .value = .{ .x = 10, .y = 10, .running = false, .eating = false, .sleeping = true, .description = "starts at Location" } },
    .{ .parent_id = 2, .timestamp = 1, .value = .{ .x = 20, .y = 10, .running = false, .eating = false, .sleeping = true, .description = "starts at Location" } },
    .{ .parent_id = 3, .timestamp = 1, .value = .{ .x = 10, .y = 20, .running = false, .eating = false, .sleeping = true, .description = "starts at Location" } },
    .{ .parent_id = 4, .timestamp = 1, .value = .{ .x = 20, .y = 20, .running = false, .eating = false, .sleeping = true, .description = "starts at Location" } },
    .{ .parent_id = 1, .timestamp = 10, .value = .{ .x = 10, .y = 10, .running = false, .eating = false, .sleeping = false, .description = "awakes" } },
    .{ .parent_id = 1, .timestamp = 20, .value = .{ .x = 20, .y = 10, .running = true, .eating = false, .sleeping = false, .description = "runs" } },
    .{ .parent_id = 2, .timestamp = 21, .value = .{ .x = 20, .y = 10, .running = false, .eating = false, .sleeping = false, .description = "awakes" } },
    .{ .parent_id = 3, .timestamp = 21, .value = .{ .x = 10, .y = 20, .running = false, .eating = false, .sleeping = false, .description = "awakes" } },
    .{ .parent_id = 2, .timestamp = 25, .value = .{ .x = 20, .y = 10, .running = true, .eating = false, .sleeping = false, .description = "runs" } },
    .{ .parent_id = 3, .timestamp = 29, .value = .{ .x = 10, .y = 20, .running = false, .eating = false, .sleeping = true, .description = "goes back to sleep" } },
    .{ .parent_id = 4, .timestamp = 30, .value = .{ .x = 20, .y = 20, .running = false, .eating = false, .sleeping = false, .description = "awakes from all the commotion" } },
    .{ .parent_id = 4, .timestamp = 40, .value = .{ .x = 20, .y = 10, .running = true, .eating = false, .sleeping = false, .description = "runs" } },
};

pub fn createTimeseries() !void {
    // start with no timeseries data on file
    std.os.unlink("db/dogs.events") catch {};

    const gpa = std.heap.page_allocator;
    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nDogs example - Dogs TableTimeseries boot initial data\n\n", .{});

    var dogDB = try datastor.Table(Dog).init(gpa, "db/dogs.db");
    defer dogDB.deinit();
    try dogDB.load();

    var eventDB = try datastor.Events(usize, DogEvent).init(gpa, "db/dogs.events");
    defer eventDB.deinit();

    // load from a non-existant file, should do nothing, and not crash freeing things that dont need to be freed
    eventDB.load() catch |err| {
        std.debug.print("Initial load of db/dogs.events == {any}\n", .{err});
    };

    std.debug.print("\nExpecting that the timeseries data for all dogs should be empty here, found = {d}\n", .{eventDB.getCount()});

    // manually setup the timeseries events to setup the events table on disk
    for (dog_events) |event| {
        try eventDB.appendWithTimestamp(event.parent_id, event.timestamp, DogEvent{
            .x = event.value.x,
            .y = event.value.y,
            .running = event.value.running,
            .eating = event.value.eating,
            .sleeping = event.value.sleeping,
            .description = try gpa.dupe(u8, event.value.description),
        });
    }

    // print out all the events in timestamp order
    std.debug.print("After all events loaded, expect a list of events in timestamp order:\n", .{});
    for (eventDB.getAll()) |event| {
        std.debug.print("{s}", .{event});
    }

    // now re-load the events from disk
    std.debug.print("Re-load all the events from disk, should clean up the old ones and create a fresh new set, without leaks\n", .{});
    try eventDB.load();

    for (eventDB.getAll()) |event| {
        std.debug.print("{s}", .{event});
    }

    // now print out Dogs in the datastor, along with an audit trail of events for each dog
    std.debug.print("\nAll dogs with audit trail:\n", .{});
    for (dogDB.items()) |dog| {
        std.debug.print("Dog {s}\n", .{dog});
        const events = try eventDB.getFor(dog.id);
        defer events.deinit();
        for (events.items) |event| {
            std.debug.print("  - At {d}: {s} -> moves to ({d},{d}) status: (Asleep:{any}, Running:{any}, Eating:{any})\n", .{
                event.timestamp,
                event.value.description,
                event.value.x,
                event.value.y,
                event.value.sleeping,
                event.value.running,
                event.value.eating,
            });
        }
    }

    // iterate through 4 timestamps and show the state of all dogs at the given timestamp
    for (0..4) |i| {
        const t: i64 = @as(i64, @intCast(i * 10 + 1));
        std.debug.print("\nState of all dogs at Timestamp {d}\n", .{t});
        for (dogDB.items()) |dog| {
            if (eventDB.getForAt(dog.id, t)) |e| {
                std.debug.print("  - {s} {s} since {d} at ({d},{d}) status: (Asleep: {any}, Running: {any}, Eating:{any})\n", .{
                    dog.value.breed,
                    e.value.description,
                    e.timestamp,
                    e.value.x,
                    e.value.y,
                    e.value.sleeping,
                    e.value.running,
                    e.value.eating,
                });
            } else unreachable;
        }
    }

    // get the latest status for each dog
    std.debug.print("\nCurrent state of all dogs, based on latest event for each\n", .{});
    for (dogDB.items()) |dog| {
        const e = eventDB.getLatestFor(dog.id).?;
        std.debug.print("  - {s} is currently doing - {s} since {d} at ({d},{d}) status: (Asleep: {any}, Running: {any}, Eating:{any})\n", .{
            dog.value.breed,
            e.value.description,
            e.timestamp,
            e.value.x,
            e.value.y,
            e.value.sleeping,
            e.value.running,
            e.value.eating,
        });
    }
}
