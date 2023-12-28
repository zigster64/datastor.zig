const std = @import("std");
const s2s = @import("s2s.zig");
const Allocator = std.mem.Allocator;

pub fn Table(comptime T: type) type {

    // sanity check the type passed in
    if (!@hasField(T, "key")) @compileError("Struct is missing a field named 'key' of type usize");

    return struct {
        const Self = @This();
        const ListType = std.AutoArrayHashMap(usize, T);
        allocator: Allocator,
        list: ListType,
        filename: []const u8,

        pub fn init(allocator: Allocator, filename: []const u8) !Self {
            return .{
                .allocator = allocator,
                .list = ListType.init(allocator),
                .filename = try allocator.dupe(u8, filename),
            };
        }

        fn freeItems(self: *Self) void {
            for (self.list.values()) |value| {
                value.free(self.allocator);
            }
        }

        pub fn deinit(self: *Self) void {
            self.freeItems();
            self.list.deinit();
            self.allocator.free(self.filename);
        }

        pub fn values(self: Self) []T {
            return self.list.values();
        }

        // append a value, autoincrementing the key field
        pub fn appendAutoIncrement(self: *Self, value: T) !void {
            var v = value; // mutable local copy, because we store a modification of the original
            v.key = self.list.count() + 1;
            try self.list.put(v.key, v);
        }

        // append a value, using the supplied key value
        pub fn append(self: *Self, value: T) !void {
            try self.list.put(value.key, value);
        }

        pub fn get(self: Self, key: usize) ?T {
            return self.list.get(key);
        }

        pub fn save(self: *Self) !void {
            const file = try std.fs.cwd().createFile(self.filename, .{});
            defer file.close();

            const writer = file.writer();

            try s2s.serialize(writer, usize, self.list.count());
            for (self.list.values()) |value| {
                try s2s.serialize(writer, T, value);
            }
        }

        pub fn load(self: *Self) !void {
            const file = try std.fs.cwd().openFile(self.filename, .{});
            defer file.close();
            const reader = file.reader();

            // clean out and free the old list before loading / allocating a new one
            self.freeItems();
            self.list.clearAndFree();

            const count = try s2s.deserialize(reader, usize);
            for (0..count) |i| {
                _ = i;

                const value = try s2s.deserializeAlloc(reader, T, self.allocator);
                try self.append(value);
            }
        }
    };
}

pub fn TableWithTimeseries(comptime T: type, comptime E: type) type {

    // sanity check the type passed in
    if (!@hasField(T, "key")) @compileError("Base Struct is missing a field named 'key' of type usize");
    if (!@hasField(E, "parent_key")) @compileError("Event Struct is missing a field named 'parent_key' of type usize");
    if (!@hasField(E, "timestamp")) @compileError("Event Struct is missing a field named 'timestamp' of type i64");

    return struct {
        const Self = @This();
        const EventsType = std.ArrayList(E);
        allocator: Allocator,
        table: Table(T),
        events: EventsType,
        events_filename: []const u8,
        mutex: std.Thread.Mutex,

        pub fn init(allocator: Allocator, base_filename: []const u8, events_filename: []const u8) !Self {
            return .{
                .allocator = allocator,
                .table = try Table(T).init(allocator, base_filename),
                .events = EventsType.init(allocator),
                .events_filename = try allocator.dupe(u8, events_filename),
                .mutex = .{},
            };
        }

        fn freeItems(self: *Self) void {
            for (self.events.values()) |value| {
                value.free(self.allocator);
            }
        }

        pub fn deinit(self: *Self) void {
            self.table.deinit();
            self.events.deinit();
            self.allocator.free(self.events_filename);
        }

        pub fn values(self: Self) []T {
            return self.table.values();
        }

        // append a value, autoincrementing the key field
        pub fn appendAutoIncrement(self: *Self, value: T) !void {
            return self.table.appendAutoIncrement(value);
        }

        // append a value, using the supplied key value
        pub fn append(self: *Self, value: T) !void {
            return self.table.append(value);
        }

        pub fn get(self: Self, key: usize) ?T {
            return self.table.get(key);
        }

        pub fn save(self: *Self) !void {
            return self.table.save();
            // NOTE - do not rewrite the events table at all, not needed
        }

        pub fn load(self: *Self) !void {
            return self.table.load();
            // TODO - load events
        }

        pub fn eventCount(self: *Self) usize {
            return self.events.items.len;
        }

        pub fn getAllEvents(self: *Self) []E {
            return self.events.items;
        }

        pub fn getEventsFor(self: *Self, key: usize) !EventsType {
            var events = EventsType.init(self.allocator);
            for (self.events.items) |event| {
                if (event.parent_key == key) {
                    try events.append(event);
                }
            }
            return events;
        }

        // add an Event to the eventList, and write to the events file
        pub fn addEvent(self: *Self, event: E) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            try self.events.append(event);
            const file = try std.fs.cwd().createFile(self.events_filename, .{ .truncate = false, .read = true });
            defer file.close();
            try file.seekFromEnd(0); // point to the end of the file to append new data
            const writer = file.writer();
            try s2s.serialize(writer, E, event);
        }

        // get the latest event for the given element in the timeseries
        pub fn latestEvent(self: *Self, key: usize) ?E {
            _ = self;
            _ = key;

            return null;
        }

        // get the event for the given element at or before the given timestamp
        // ie - returns the state of the given element at a point in time
        pub fn eventAt(self: *Self, key: usize, timestamp: i64) ?E {
            _ = self;
            _ = key;
            _ = timestamp;

            return null;
        }
    };
}
