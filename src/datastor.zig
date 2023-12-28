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
        allocator: Allocator,
        values: std.AutoArrayHashMap(usize, T),

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .values = std.AutoArrayHashMap(usize, T).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.values.deinit();
        }

        // append a value, autoincrementing the key field
        pub fn appendAutoIncrement(self: *Self, value: T) !void {
            var v = value; // mutable local copy, because we store a modification of the original
            v.key = self.values.count() + 1;
            try self.values.put(v.key, v);
        }

        // append a value, using the supplied key value
        pub fn append(self: *Self, value: T) !void {
            try self.values.put(value.key, value);
        }

        pub fn save(self: *Self, filename: []const u8) !void {
            const file = try std.fs.cwd().createFile(filename, .{});
            defer file.close();

            const writer = file.writer();

            for (self.values.values()) |value| {
                try s2s.serialize(writer, T, value);
            }
        }
    };
}
