const std = @import("std");
const s2s = @import("s2s.zig");
const Allocator = std.mem.Allocator;

//========================================================================================================
// TABLE section
//
// An Item is a wrapper struct around a type that is used as a record in a table
pub fn Item(comptime K: type, comptime T: type) type {
    return struct {
        const Self = @This();
        id: K = undefined,
        value: T = undefined,

        pub fn free(self: Self, allocator: Allocator) void {
            if (std.meta.hasFn(T, "free")) {
                self.value.free(allocator);
            }
        }

        pub fn newID(self: *Self, count: usize) K {
            if (std.meta.hasFn(T, "newID")) {
                return self.value.newID(count);
            }
            return count;
        }

        pub fn format(item: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = options;
            _ = layout;

            try std.fmt.format(writer, "id: {any} value: {}", .{ item.id, item.value });
        }
    };
}

pub fn Table(comptime K: type, comptime T: type) type {
    return struct {
        const Self = @This();
        const ItemType = Item(K, T);
        const ListType = std.AutoArrayHashMap(K, ItemType);
        const ArrayType = std.ArrayList(ItemType);
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
            if (std.meta.hasFn(T, "free")) {
                for (self.list.values()) |value| {
                    value.free(self.allocator);
                }
            }
        }

        pub fn deinit(self: *Self) void {
            self.freeItems();
            self.list.deinit();
            self.allocator.free(self.filename);
        }

        pub fn items(self: Self) []ItemType {
            return self.list.values();
        }

        // append a value, autoincrementing the id field
        pub fn append(self: *Self, value: T) !K {
            var item = ItemType{
                .value = value,
            };
            item.id = item.newID(self.list.count() + 1);
            try self.list.put(item.id, item);
            self.dirty = true;
            return item.id;
        }

        // put a value, using the supplied key and value
        pub fn put(self: *Self, id: K, value: T) !void {
            try self.list.put(id, ItemType{
                .id = id,
                .value = value,
            });
            self.dirty = true;
        }

        // put a value into a tree, using the supplied key, parent ID, and value
        pub fn putTree(self: *Self, id: K, parent_id: K, value: T) !void {
            try self.list.put(id, ItemType{
                .id = id,
                .parent_id = parent_id,
                .value = value,
            });
            self.dirty = true;
        }

        pub fn get(self: Self, id: K) ?ItemType {
            return self.list.get(id);
        }

        pub fn save(self: *Self) !void {
            if (!self.dirty) return;
            const file = try std.fs.cwd().createFile(self.filename, .{});
            defer file.close();

            const writer = file.writer();

            try s2s.serialize(writer, usize, self.list.count());
            for (self.list.values()) |item| {
                try s2s.serialize(writer, ItemType, item);
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

                const item = try s2s.deserializeAlloc(reader, ItemType, self.allocator);
                try self.list.put(item.id, item);
            }
            self.dirty = false;
        }

        // Tree support  functions
        pub fn getChildrenCount(self: Self, parent_id: K) !usize {
            var count: usize = 0;
            for (self.list.values()) |value| {
                // TODO equality operator
                if (value.parent_id == parent_id) {
                    count += 1;
                }
            }
            return count;
        }

        pub fn getChildren(self: Self, parent_id: usize) !ArrayType {
            var children = ArrayType.init(self.allocator);
            for (self.list.values()) |value| {
                // TODO equality operator
                if (value.parent_id == parent_id) {
                    try children.append(value);
                }
            }
            return children;
        }
    };
}

//========================================================================================================
//TIMESERIES section
//
// An Event is a wrapper struct around a type that is used as a timeseries record attached to a table Item
pub fn Event(comptime PK: type, comptime T: type) type {
    return struct {
        const Self = @This();
        parent_id: PK = undefined,
        timestamp: i64 = undefined,
        value: T = undefined,

        pub fn free(self: Self, allocator: Allocator) void {
            if (std.meta.hasFn(T, "free")) {
                self.value.free(allocator);
            }
        }

        pub fn format(event: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = options;
            _ = layout;

            try std.fmt.format(writer, "parent_id: {any} timestamp: {d} value: {}", .{ event.parent_id, event.timestamp, event.value });
        }
    };
}

pub fn Events(comptime K: type, comptime T: type) type {
    return struct {
        const Self = @This();
        const EventType = Event(K, T);
        const ListType = std.ArrayList(EventType);
        allocator: Allocator,
        mutex: std.Thread.Mutex,
        list: ListType,
        filename: []const u8,

        pub fn init(allocator: Allocator, filename: []const u8) !Self {
            return .{
                .allocator = allocator,
                .mutex = .{},
                .list = ListType.init(allocator),
                .filename = try allocator.dupe(u8, filename),
            };
        }

        pub fn freeItems(self: *Self) void {
            if (std.meta.hasFn(T, "free")) {
                for (self.list.items) |value| {
                    value.free(self.allocator);
                }
            }
        }

        pub fn deinit(self: *Self) void {
            self.freeItems();
            self.list.deinit();
            self.allocator.free(self.filename);
        }

        pub fn getCount(self: Self) usize {
            return self.list.items.len;
        }

        pub fn getCountFor(self: Self, parent_id: K) usize {
            var count: usize = 0;
            for (self.list.items) |item| {
                // TODO equality operator
                if (item.parent_id == parent_id) {
                    count += 1;
                }
            }
            return count;
        }

        pub fn load(self: *Self) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            // clean out and free the old list before loading / allocating a new one
            self.freeItems();
            self.list.clearAndFree();

            const file = try std.fs.cwd().openFile(self.filename, .{});
            defer file.close();
            while (true) {
                const event = s2s.deserializeAlloc(file.reader(), EventType, self.allocator) catch |err| {
                    switch (err) {
                        error.EndOfStream => return, // this is expected
                        else => return err,
                    }
                };
                try self.list.append(event);
            }
        }

        pub fn append(self: *Self, parent_id: K, value: T) !void {
            try self.appendWithTimestamp(parent_id, std.time.timestamp(), value);
        }

        pub fn appendWithTimestamp(self: *Self, parent_id: K, timestamp: i64, value: T) !void {
            const event = EventType{
                .parent_id = parent_id,
                .timestamp = timestamp,
                .value = value,
            };

            // use a mutex to lock disk IO
            self.mutex.lock();
            defer self.mutex.unlock();

            // add it to the in-memory table
            try self.list.append(event);

            // append to disk
            const file = try std.fs.cwd().createFile(self.filename, .{ .truncate = false, .read = true });
            defer file.close();
            try file.seekFromEnd(0); // point to the end of the file to append new data
            const writer = file.writer();
            try s2s.serialize(writer, EventType, event);
        }

        pub fn getAll(self: Self) []EventType {
            return self.list.items;
        }

        // for returns a list of events FOR the given parent
        pub fn getFor(self: Self, parent_id: K) !ListType {
            var events = ListType.init(self.allocator);
            for (self.list.items) |item| {
                // TODO equality operator
                if (item.parent_id == parent_id) {
                    try events.append(item);
                }
            }
            return events;
        }

        pub fn getAt(self: Self, timestamp: i64) ?EventType {
            var last_event: ?EventType = null;
            for (self.list.items) |event| {
                if (event.timestamp > timestamp) return last_event;
                last_event = event;
            }
            return last_event;
        }

        pub fn getForAt(self: Self, parent_id: K, timestamp: i64) ?EventType {
            var last_event: ?EventType = null;
            for (self.list.items) |event| {
                if (event.timestamp > timestamp) return last_event;
                // TODO equality operator
                if (event.parent_id == parent_id) last_event = event;
            }
            return last_event;
        }

        pub fn getLatest(self: Self) ?EventType {
            const i = self.list.items.len;
            if (i > 0) {
                return self.list[i - 1];
            }
            return null;
        }

        pub fn getLatestFor(self: Self, parent_id: K) ?EventType {
            var i = self.list.items.len;
            while (i > 0) {
                i -= 1;
                const event = self.list.items[i];
                // TODO equality operator
                if (event.parent_id == parent_id) {
                    return event;
                }
            }
            return null;
        }
    };
}
