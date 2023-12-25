const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Store() type {
    return struct {
        allocator: Allocator,
        filename: []const u8,

        const Self = @This();

        pub fn init(allocator: Allocator, filename: []const u8) !Self {
            return .{
                .allocator = allocator,
                .filename = try allocator.dup(filename),
            };
        }
    };
}
