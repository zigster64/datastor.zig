const std = @import("std");
const s2s = @import("s2s.zig");
const Allocator = std.mem.Allocator;

pub fn Item(comptime K: type, comptime T: type) type {
    return struct {
        const Self = @This();
        id: K = undefined,
        parent_id: K = undefined,
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
        is_tree: bool = false,

        pub fn init(allocator: Allocator, filename: []const u8) !Self {
            var is_tree = false;
            switch (@typeInfo(T)) {
                .Struct => |_| {
                    is_tree = @hasField(T, "parent_id");
                },
                .Union => |_| {
                    is_tree = std.meta.hasFn(T, "getParentID") and std.meta.hasFn(T, "setParentID");
                },
                else => {
                    @compileError(T);
                },
            }
            return .{
                .allocator = allocator,
                .list = ListType.init(allocator),
                .filename = try allocator.dupe(u8, filename),
                .is_tree = is_tree,
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

        pub fn values(self: Self) []ItemType {
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

        // put a value, using the supplied id value
        pub fn put(self: *Self, id: K, value: T) !void {
            try self.list.put(id, ItemType{
                .id = id,
                .value = value,
            });
            self.dirty = true;
        }

        // put a value into a tree, using the supplied id value
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
            for (self.list.values()) |value| {
                try s2s.serialize(writer, ItemType, value);
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
                if (value.parent_id == parent_id) {
                    count += 1;
                }
            }
            return count;
        }

        pub fn getChildren(self: Self, parent_id: usize) !ArrayType {
            var children = ArrayType.init(self.allocator);
            for (self.list.values()) |value| {
                if (value.parent_id == parent_id) {
                    try children.append(value);
                }
            }
            return children;
        }
    };
}
