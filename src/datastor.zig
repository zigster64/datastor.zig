const std = @import("std");
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

        // append a value, upd
        pub fn appendAutoIncrement(self: *Self, value: T) !void {
            var v = value; // mutable local copy, because we store a modification of the original
            v.key = self.values.count() + 1;
            try self.values.put(v.key, v);
        }

        pub fn saveTxt(self: *Self, filename: []const u8) !void {
            const file = try std.fs.cwd().createFile(filename, .{});
            defer file.close();

            const writer = file.writer();

            for (self.values.values()) |value| {
                try writer.print("{}\n", .{value});
            }
        }

        pub fn save(self: *Self, filename: []const u8) !void {
            const file = try std.fs.cwd().createFile(filename, .{});
            defer file.close();

            const writer = file.writer();

            for (self.values.values()) |value| {
                try self.serialize(value, writer);
            }
        }

        // at this point, clone and modify MasterQ32 s2s library
        // which is the closest to what I want here
        fn serialize(self: Self, value: T, writer: anytype) !void {
            _ = self;
            _ = value;
            _ = writer;

            const TypeInfo = @typeInfo(T);
            switch (TypeInfo) {
                .Struct => |structInfo| {
                    for (structInfo.fields) |field| {
                        std.debug.print("Field name: {}, Field type: {}\n", .{ field.name, field.field_type });
                    }
                },
                else => @compileError("datastor only works on structs"),
            }
        }
    };
}
