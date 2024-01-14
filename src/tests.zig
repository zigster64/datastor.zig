const std = @import("std");
const datastor = @import("datastor");
const expect = std.testing.expect;

const Customer = struct {
    name: []const u8 = undefined,
    address: []const u8 = undefined,
    balance: u32 = 0,
};

test "Table with Serial key" {
    const filename = "./_test_db/customer_serial.db";
    std.os.unlink(filename) catch {};

    const CustomerDB = datastor.Table(Customer);
    var customers = try CustomerDB.init(std.testing.allocator, filename);
    defer customers.deinit();

    // create some customers and save them
    const id1 = try customers.append(.{ .name = "John", .address = "123 Main St", .balance = 100 });
    try expect(id1 == 1);

    const id2 = try customers.append(.{ .name = "Jack", .address = "234 Main St", .balance = 200 });
    try expect(id2 == 2);

    try customers.save();
    defer std.os.unlink(filename) catch {};

    // check that the generated file is the right size
    const file = try std.fs.cwd().openFile(filename, .{});
    const stat = try file.stat();
    try expect(stat.size == 118); // 118 bytes - this assumes usize is 64bits, will fail on 32bit or other arch ?
}
