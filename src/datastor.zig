const std = @import("std");
const s2s = @import("s2s.zig");
const Allocator = std.mem.Allocator;

//========================================================================================================
// KEY types
const KeyType = enum {
    serial,
    uuid,
    string,
    custom,
};

//========================================================================================================
// TABLE section
//
// An Item is a wrapper struct around a type that is used as a record in a table
pub fn Item(comptime K: type, comptime T: type) type {
    return struct {
        const Self = @This();
        id: K = undefined,
        value: T = undefined,

        pub fn free(self: Self, allocator: Allocator, comptime KT: KeyType) void {
            if (KT == .string) {
                allocator.free(self.id);
            }
            if (std.meta.hasFn(T, "free")) {
                self.value.free(allocator);
            }
        }

        pub fn newID(self: *Self, allocator: Allocator, count: usize) !K {
            if (std.meta.hasFn(T, "newID")) {
                return self.value.newID(allocator, count);
            }
            return count;
        }

        pub fn format(item: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = options;
            _ = layout;

            try std.fmt.format(writer, "id: {any} value: {}", item);
        }
    };
}

// variant of an Item that is a node in a tree
pub fn ItemNode(comptime K: type, comptime T: type) type {
    return struct {
        const Self = @This();
        id: K = undefined,
        parent_id: K = undefined,
        value: T = undefined,

        pub fn free(self: Self, allocator: Allocator, comptime KT: KeyType) void {
            if (KT == .string) {
                allocator.free(self.id);
            }
            if (std.meta.hasFn(T, "free")) {
                self.value.free(allocator);
            }
        }

        pub fn newID(self: *Self, allocator: Allocator, count: usize) !K {
            if (std.meta.hasFn(T, "newID")) {
                return self.value.newID(allocator, count);
            }
            return count;
        }

        pub fn newNodeID(self: *Self, allocator: Allocator, parent_id: K, count: usize, parent_count: usize) !K {
            if (std.meta.hasFn(T, "newNodeID")) {
                return self.value.newNodeID(allocator, parent_id, count, parent_count);
            }
            return self.newID(allocator, count);
        }

        pub fn format(item: Self, comptime layout: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = options;
            _ = layout;

            try std.fmt.format(writer, "id: {any}, parent: {any}, value: {}", item);
        }
    };
}

pub fn Table(comptime T: type) type {
    return Datastore(.serial, usize, T, false);
}

pub fn TableWithKey(comptime T: type, comptime KT: KeyType) type {
    switch (KT) {
        .serial => return Datastore(.serial, usize, T, false),
        .uuid => return Datastore(.uuid, u128, T, false),
        .string => return Datastore(.string, []const u8, T, false),
        .custom => @compileError("Custom key type not yet supported"),
    }
}

pub fn Tree(comptime T: type) type {
    return Datastore(.serial, usize, T, true);
}

pub fn TreeWithKey(comptime T: type, comptime KT: KeyType) type {
    switch (KT) {
        .serial => return Datastore(.serial, usize, T, true),
        .uuid => return Datastore(.uuid, u128, T, true),
        .string => return Datastore(.string, []const u8, T, true),
        .custom => @compileError("Custom key type not yet supported"),
    }
}

pub fn Datastore(comptime KT: KeyType, comptime K: type, comptime T: type, comptime is_tree: bool) type {
    return struct {
        const Self = @This();
        const ItemType = if (is_tree) ItemNode(K, T) else Item(K, T);
        const ListType = if (KT == .string) std.StringArrayHashMap(ItemType) else std.AutoArrayHashMap(K, ItemType);
        const ArrayType = std.ArrayList(ItemType);
        allocator: Allocator,
        list: ListType,
        filename: []const u8,
        is_tree: bool,
        dirty: bool = false,

        pub fn init(allocator: Allocator, filename: []const u8) !Self {
            return .{
                .allocator = allocator,
                .list = ListType.init(allocator),
                .filename = try allocator.dupe(u8, filename),
                .is_tree = is_tree,
            };
        }

        fn freeItems(self: *Self) void {
            for (self.list.values()) |item| {
                item.free(self.allocator, KT);
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
            item.id = try item.newID(self.allocator, self.list.count() + 1);
            try self.list.put(item.id, item);
            self.dirty = true;
            return item.id;
        }

        // append a value to a parent node, autoincrementing the id field
        pub fn appendNode(self: *Self, parent_id: K, value: T) !K {
            if (!is_tree) @compileError("appendNode() only works on Tree type datastores. Try using datastor.Tree() instead of datastor.Table() ?");
            var item = ItemType{
                .parent_id = parent_id,
                .value = value,
            };
            // enables the base class to have a custom override for the autoincr ID
            // based on the seq number in the whole DB as well as the seq number relative
            // to the parent
            item.id = try item.newNodeID(
                self.allocator,
                parent_id,
                self.list.count() + 1,
                self.getChildrenCount(parent_id) + 1,
            );
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
        pub fn putNode(self: *Self, parent_id: K, id: K, value: T) !void {
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
        pub fn getChildrenCount(self: Self, parent_id: K) usize {
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
