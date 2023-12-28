const std = @import("std");
const s2s = @import("s2s.zig");
const Allocator = std.mem.Allocator;

const Options = struct {
    timeseries: bool = false,
    tree: bool = false,
};

pub fn Table(comptime T: type) type {
    return Store(T, .{});
}

pub fn Store(comptime T: type, comptime options: Options) type {
    _ = options;

    // sanity check the type passed in
    if (!@hasField(T, "key")) @compileError("Struct is missing a field named 'key' of type usize");

    return struct {
        const Self = @This();
        const ListType = std.AutoArrayHashMap(usize, T);
        allocator: Allocator,
        list: ListType,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .list = ListType.init(allocator),
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

        pub fn save(self: *Self, filename: []const u8) !void {
            const file = try std.fs.cwd().createFile(filename, .{});
            defer file.close();

            const writer = file.writer();

            try s2s.serialize(writer, usize, self.list.count());
            for (self.list.values()) |value| {
                try s2s.serialize(writer, T, value);
            }
        }

        pub fn load(self: *Self, filename: []const u8) !void {
            const file = try std.fs.cwd().openFile(filename, .{});
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
