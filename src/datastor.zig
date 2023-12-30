const std = @import("std");
const s2s = @import("s2s.zig");
const Allocator = std.mem.Allocator;

pub fn Table(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Struct => |_| {
            // sanity check the type passed in
            if (!@hasField(T, "id")) @compileError("Struct is missing a field named 'id' of type usize");
        },
        .Union => |u| {
            const Tag = u.tag_type orelse @compileError("Untagged unions are not supported!");
            _ = Tag;
        },
        else => {
            @compileError(T);
        },
    }

    return struct {
        const Self = @This();
        const ListType = std.AutoArrayHashMap(usize, T);
        allocator: Allocator,
        list: ListType,
        filename: []const u8,
        dirty: bool = false,

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

        // getID gets the ID from the value - it understands unions
        fn getID(value: T) usize {
            switch (@typeInfo(T)) {
                .Struct => |_| {
                    return value.id;
                },
                .Union => |_| {
                    return value.getID();
                },
                else => {
                    @compileError(T);
                },
            }
        }

        // setID sets the value of id in the type passed. Understands unions
        fn setID(value: *T, id: usize) void {
            switch (@typeInfo(T)) {
                .Struct => |_| {
                    value.id = id;
                },
                .Union => |_| {
                    value.setID(id);
                },
                else => {
                    @compileError(T);
                },
            }
        }

        // append a value, autoincrementing the id field
        pub fn append(self: *Self, value: T) !void {
            const id = self.list.count() + 1;
            var v = value;
            setID(&v, id);
            try self.list.put(id, v);
            self.dirty = true;
        }

        // put a value, using the supplied id value
        pub fn put(self: *Self, value: anytype) !void {
            try self.list.put(getID(value), value);
            self.dirty = true;
        }

        pub fn get(self: Self, id: usize) ?T {
            return self.list.get(id);
        }

        pub fn save(self: *Self) !void {
            if (!self.dirty) return;
            const file = try std.fs.cwd().createFile(self.filename, .{});
            defer file.close();

            const writer = file.writer();

            try s2s.serialize(writer, usize, self.list.count());
            for (self.list.values()) |value| {
                try s2s.serialize(writer, T, value);
            }
            self.dirty = false;
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
                try self.put(value);
            }
            self.dirty = false;
        }
    };
}

pub fn TableWithTimeseries(comptime T: type, comptime E: type) type {
    switch (@typeInfo(T)) {
        .Struct => |_| {
            // sanity check the type passed in
            if (!@hasField(T, "id")) @compileError("Base Struct is missing a field named 'id' of type usize");
            if (!@hasField(E, "parent_id")) @compileError("Event Struct is missing a field named 'parent_id' of type usize");
            if (!@hasField(E, "timestamp")) @compileError("Event Struct is missing a field named 'timestamp' of type i64");
        },
        .Union => |u| {
            const Tag = u.tag_type orelse @compileError("Untagged unions are not supported!");
            _ = Tag;
        },
        else => unreachable,
    }

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

        // append a value, autoincrementing the id field
        pub fn append(self: *Self, value: T) !void {
            return self.table.append(value);
        }

        pub fn get(self: Self, id: usize) ?T {
            return self.table.get(id);
        }

        pub fn put(self: *Self, value: T) !void {
            try self.list.put(value.id, value);
        }

        pub fn save(self: *Self) !void {
            return self.table.save();
            // NOTE - do not rewrite the events table at all, not needed
        }

        pub fn load(self: *Self) !void {
            return self.table.load();
            // TODO - load events
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

        pub fn eventCount(self: *Self) usize {
            return self.events.items.len;
        }

        pub fn eventCountFor(self: *Self, id: usize) usize {
            var i: usize = 0;
            for (self.events.items) |event| {
                if (event.parent_id == id) {
                    i += 1;
                }
            }
            return i;
        }

        pub fn getAllEvents(self: *Self) []E {
            return self.events.items;
        }

        pub fn getEventsBetween(self: *Self, from: i64, to: i64) !EventsType {
            var events = EventsType.init(self.allocator);
            for (self.events.items) |event| {
                if (event.timestamp >= from and event.timestamp <= to) {
                    try events.append(event);
                }
            }
            return events;
        }

        pub fn getEventsFor(self: *Self, id: usize) !EventsType {
            var events = EventsType.init(self.allocator);
            for (self.events.items) |event| {
                if (event.parent_id == id) {
                    try events.append(event);
                }
            }
            return events;
        }

        pub fn getEventsForBetween(self: *Self, id: usize, from: i64, to: i64) !EventsType {
            var events = EventsType.init(self.allocator);
            for (self.events.items) |event| {
                if (event.parent_id == id and event.timestamp >= from and event.timestamp <= to) {
                    try events.append(event);
                }
            }
            return events;
        }

        // get the latest event for the given element in the timeseries
        pub fn latestEvent(self: *Self, id: usize) ?E {
            var i = self.events.items.len;
            while (i > 0) {
                i -= 1;
                const event = self.events.items[i];
                if (event.parent_id == id) {
                    return event;
                }
            }
            return null;
        }

        // get the event for the given element at or before the given timestamp
        // ie - returns the state of the given element at a point in time
        pub fn eventAt(self: *Self, id: usize, timestamp: i64) ?E {
            var last_event: ?E = null;
            for (self.events.items) |event| {
                if (event.timestamp > timestamp) return last_event;
                if (event.parent_id == id) last_event = event;
            }
            return last_event;
        }
    };
}
