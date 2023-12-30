const std = @import("std");
const datastor = @import("datastor");

const cats = @import("cats.zig");
const dogs = @import("dogs.zig");

const Allocator = std.mem.Allocator;
const Cat = cats.Cat;
const CatEvent = cats.CatEvent;
const Dog = dogs.Dog;
const DogEvent = dogs.DogEvent;

const AnimalType = enum { cat, dog, bird };

const Animal = union(AnimalType) {
    const Self = @This();

    cat: cats.Cat,
    dog: dogs.Dog,
    bird: void, // uncovered case

    pub fn free(self: Self, allocator: Allocator) void {
        switch (self) {
            .cat => self.cat.free(allocator),
            .dog => self.dog.free(allocator),
            .bird => {},
        }
    }
};

pub fn createSimpleTable() !void {
    std.os.unlink("db/animals.db") catch {};

    const gpa = std.heap.page_allocator;

    std.debug.print("------------------------------------------------\n", .{});
    std.debug.print("\nAnimals (union) example - save simple data set to table\n\n", .{});

    // create a datastor to store the animals
    var animalDB = try datastor.Table(Animal).init(gpa, "db/animals.db");
    defer animalDB.deinit();

    // add a cat
    try animalDB.append(Animal{
        .cat = .{
            .breed = try gpa.dupe(u8, "Siamese"),
            .color = try gpa.dupe(u8, "Sliver"),
            .length = 28,
            .aggression = 0.9,
        },
    });

    // add a dog
    try animalDB.append(Animal{
        .dog = .{
            .breed = try gpa.dupe(u8, "Colley"),
            .color = try gpa.dupe(u8, "Black and White"),
            .height = 33,
            .appetite = 0.9,
        },
    });

    animalDB.dirty = true;
    try animalDB.save();
}
