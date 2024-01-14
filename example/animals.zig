const std = @import("std");
const datastor = @import("datastor");

const cats = @import("cats.zig");
const dogs = @import("dogs.zig");

const Allocator = std.mem.Allocator;
const Cat = cats.Cat;
const CatEvent = cats.CatEvent;
const Dog = dogs.Dog;
const DogEvent = dogs.DogEvent;

const AnimalType = enum { cat, dog };

const Animal = union(AnimalType) {
    const Self = @This();

    cat: cats.Cat,
    dog: dogs.Dog,

    pub fn free(self: Self, allocator: Allocator) void {
        switch (self) {
            .cat => |cat| cat.free(allocator),
            .dog => |dog| dog.free(allocator),
        }
    }
};

pub fn createTable() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const gpa = general_purpose_allocator.allocator();

    std.os.unlink("db/animals.db") catch {};

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nAnimals (union) example - save simple data set to table\n\n", .{});

    // create a datastor to store the animals
    var animalDB = try datastor.Table(Animal).init(gpa, "db/animals.db");
    defer animalDB.deinit();

    // add a cat
    _ = try animalDB.append(Animal{
        .cat = .{
            .breed = try gpa.dupe(u8, "Siamese"),
            .color = try gpa.dupe(u8, "Sliver"),
            .length = 28,
            .aggression = 0.9,
        },
    });

    // add a dog
    _ = try animalDB.append(Animal{
        .dog = .{
            .breed = try gpa.dupe(u8, "Colley"),
            .color = try gpa.dupe(u8, "Black and White"),
            .height = 33,
            .appetite = 0.9,
        },
    });

    try animalDB.save();
}

pub fn loadTable() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const gpa = general_purpose_allocator.allocator();

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nAnimals (union) example - load simple data set from disk\n\n", .{});

    // create a datastor to store the animals
    var animalDB = try datastor.Table(Animal).init(gpa, "db/animals.db");
    defer animalDB.deinit();

    try animalDB.load();
    for (animalDB.items(), 0..) |animal, i| {
        std.debug.print("Animal {d} is {any}:\n", .{ i, animal });
    }
}
