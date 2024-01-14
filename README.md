# datastor.zig

Fast & Light Data persistence layer for Zig

Intended use is for:

- Object persistence using local storage, for edge / IoT / local game world, etc
- Thread safe for use in a single process only
- Persist Table, Timeseries and Tree structured data
- Situations where using an external DB would be overkill
- Where performance is more important than general flexibility

Not intended for :

- Any situation where the entire dataset will not fit in memory
- Scalable, multi-process database backends.
- General Purpose data persistence. Datastor has a highly opinionated approach to dealing with Static vs Timeseries data. That may not suit the way your data is structured.
- Current data format uses native `usize` quite a bit, so the datafiles are not 100% portable between machines with different word sizes.

For any of the "Not Intended" use cases above, best look at options such as SQLite, DuckDB, or server based PostgreSQL w/ TimeseriesDB extensions over the network.

References:

- [Postgres Libraries for Zig](http://github.com/karlseguin/pg.zig)
- [DuckDB Libraries for Zig](http://github.com/karlseguin/zuckdb.zig)
- [SQLite for Zig](https://github.com/search?q=zig%20sqlite&type=repositories)

On disk format uses S2S format for object storage
(see https://github.com/ziglibs/s2s)

S2S is battle tested code, but it does lack a few types that it can serialize out of the box. You can code around this
easy enough, but its something you should be aware of.

## Version Log

- Dec 2023 - v0.0.0 - init project
- Jan 2024 - v0.2.0 - new key types (serial / uuid / string)

----

## Project Scope - how it works

`datastor.zig` provides an embedded "Object Persistence" API for collections of Zig Types.

In concept, A Datastor is a light comptime wrapper around your struct, that provides :

- An ordered HashMap collection of elements, synched to disk
- CRUD operations against that collection
- A single 'primary key' stored as extra metadata against the user-supplied struct
- Primary Keys can be one of : (Serial Number, UUID, Custom String)
- Timeseries extension, to provide each record in a Table with an unlimited audit trail of state transitions
- Timeseries handy functions to get element state at a point in time / events over a period, etc
- Handles tagged union data, so each table may store multiple variants of a type, but still using a strict schema across types
- Handles Tree structured data, so you can optionally overlay a heirachy on top of your collection
- Utility functions for tree data to reparent nodes, or move nodes up and down within their parent block

---

# Types of Datastore

## [Table Data](#table-data)

For 2D Tables, where each row is an instance of your data struct, with additional metadata to record the key, etc.

Example: A Table of Customer information.

## [Tree Data](#tree-data)

For Tree structured data, where each row is an instance of your data struct, with additional metadata that references the parent row.

Example: A Tree of Projects within a Heirachy of Projects

## [Timeseries Data](#timeseries-data)

For streaming / event / state transition data, where each row is an instance of your event data, with additional metadata to 
reference the parent record, and a timestamp for when the record was created.

Example: Lets say we have a game, with a Table of 'Monster'.  We can add a Timeseries datastore, which tracks the (x,y) location and current HitPoints
of any Monster at each turn in the game. This keeps the original Monster table un-modified, and tracks an audit trail of state transitions for 
all monsters in a separate timeseries array.

---

# Operations on a Datastore

| Function | Description | Notes |
|---|---|---|
| load() | Loads the Datastore from disk | |
| save() | Saves the Datastore to disk | |
| items() []Record | Returns an ordered ArrayList of all items in the datastore | Caller owns the ArrayList, must free() after use |
| append(Value) Key | Add an item to the datastore. Will compute a new primary key for the record | Returns the value of the newly computed primary key for the new record |
| put(Key, Value) | Updates the Value of the record with the given Key ||
| get(Key) Record | Returns the record with the given Key ||
| delete(Key) | Deletes the record with the given Key | "Deleted" Records are kept on disk, but marked as invalid |
| vacuum() | Vacuum will strip out all deleted records from the datastore, and re-number the SERIAL primary keys, plus any referenced records in Timeseries datastores ||
| select(filterFn) []Record | Returns an ordered ArrayList of all the items that match the given filter. The filter is a function that takes the record value, and returns true if it matches | Caller owns the ArrayList, and must free() after use |
| migrate(OldStruct, NewStruct) | Converts existing datastores from the old record structure to a new record structure ||



---

# Types of Keys

## SERIAL

Tables with a SERIAL primary key. 

When a new record is added to a Table, it automatically gets assigned to (NUMBER OF RECORDS + 1)

## UUID

UUID primary keys generate a new random UUIDv4 value when new records are created

## String

A String key is a custom user-generated key for new records

The owning structure must define a function to generate a new key based on the record contents, and the record number

For Table datastores :
`pub fn newID(self, allocator, record_number) []const u8`

For Tree datastores, optionally include this function :

`pub fn newNodeID(self, allocator, parent_key, record_number, sibling_count) []const u8`
... or fallback to `newID()` if not provided


---


# Table Data

---

# Tree Data

--- 

## Timeseries Data

---




## Intial State information vs State Transitions

Datastor takes a highly opinionated approach to separating data persistence between "Static" data, and "Timeseries" data.

Static data is for :
- Initial State data / config / assets
- May be updated occassionally after initial boot
- Static data is explicitly loaded and saved to and from disk using functions `table.load()` and `table.save()`
- There is no per-record disk I/O. `load()` loads the whole table from disk, and `save()` saves the whole table to disk

Timeseries data is for :
- Recording state transitions in the static data, after system start
- Timestamped audit trail of events for each element of static data
- Timeseries data is loaded on `table.load()`, and automatically appended to disk on every `table.addEvent(Event)`
- Disk I/O is per record - everytime a new timeseries event is added


The API considers that the initial state of an Item, and its collection of events over time, form a single Coherent Entity with a single logical API.

On disk, its splits these into 2 files - 1 file for the initial Static data, that is only occassionally updated (if ever), and 1 other file for the timeseries / event 
data, that is frequently appended to.

The Datastor API then wraps this as a single storage item.

---
# Wrapped DataType

For any given struct T, the datastor will maintain a collection of 

ItemType(T)

Which is a wrapper around your original struct T.

This ItemType(T) wrapper includes extra fields such as the unique ID of this record, the ID of the parent record, etc.

Example - creating a datastor on this type :
```zig
const MyDataType = struct {
  x: usize,
  y: usize,
}
```

using Key type `usize`, will create a wrapper object around MyDataType that adds an `id` field of type usize, and several extra convenience functions.

ie
```zig
struct {
  id: usize,
  value: MyDataType,
}
```

When you `put()` or `append()` to the datastor, you pass in `MyDataType`

When you `get()` or iterate over the `items()` in the datastor, you get back the Wrapped type, so you have access to the 
unique ID associated with your original data.

ie:
```zig
for (db.items()) |item| {
   std.debug.print("Item with ID {d}:", .{item.id});
   std.debug.print("Value: {}\n", .{item.value});
}
```
---

TODO - rewrite from here down


# API Overview

## For Static-only data :

| Function | Description |
|----------|-------------|
| Table(comptime K:type, comptime T:type) |  Returns a Table object that wraps a collection of (struct) T<br><br>T must have a function `free()` if it contains fields that are allocated on load (such as strings) | 
| table.init(Allocator, filename: []const u8) | Initialises the Table |
| table.deinit()                              | Free any memory resources consumed by the Table |
| | |
| table.load() !void                          | Explicitly load the collection from disk |
| table.save() !void                          | Explicitly save the data to disk |
| | |
| table.items() []Item                          | Returns a slice of all the items in the Table, in insertion order |
| table.get(id) ?Item                            | Gets the element of type T, with the given ID (or null if not found) |
| | |
| table.put(T)                                | Add or overwrite element of type T to the Table. Does not write to disk yet. Batch up many updates, then call `save()` once | 
| table.append(T) usize  (Autoincrement !)          | Adds a new element of type T to the table, setting the ID of the new record to the next value in sequence. Returns the new ID<br><br>If the base type has a function `newID(count: usize) KeyType`, then it uses that to get the next Key value |


Autoincrement note - Datatsor calculates the 'next sequence' as `Table.len + 1`, which is quick and simple enough. 
If loading data into a datastor, then use one method or the other, but avoid mixing them together, as the ID forms the key in the hashtable.

## For Static + Timeseries data :

| Function | Description |
|----------|-------------|
| TableWithTimeseries(comptime T:type, comptime EventT: type) |  Returns a Table object that wraps a collection of (struct) T, with an unlimited array of EventT events attached<br><br>T must have a field named `id:usize` that uniquely identifies the record<br>T must have a function `free()` if it contains fields that are allocated on load (such as strings)<br><br>EventT must have a field named `parent_id:usize` and `timestamp:i64` | 
| table.init(Allocator, table_filename: []const u8, event_filename: []const u8) | Initialises the Table  |
| table.deinit()                              | Free any memory resources consumed by the Table |
| | |
| table.load() !void                          | Explicitly load the collection from disk |
| table.save() !void                          | Explicitly save the data to disk |
| | |
| table.items() []T                          | Returns a slice of all the items in the Table, in insertion order |
| table.get(id) ?T                           | Gets the element of type T, with the given ID (or null if not found) |
| | |
| table.put(T)                                | Add or overwrite element of type T to the Table. Does not write to disk yet. Batch up many updates, then call `save()` once | 
| table.append(T) usize  (Autoincrement !)          | Adds a new element of type T to the table, setting the ID of the new record to the next value in sequence. Returns the new ID |
| | |
| Timeseries Functions | |
| table.eventCount() usize                    | How many events all up ? |
| table.eventCountFor(id: usize) usize       | How many events for the given element ?|
| | |
| table.getAllEvents() []EventT               | Get all the events for all elements in this datastor, in timestamp order |
| table.getEventsBetween(from, to: i64) ArrayList(EventT) | Get an ArrayList of all events between to 2 timestamps.<br><br>Caller owns the list and must `deinit()` after use |
| table.getEventsFor(id: usize) ArrayList(EventT) | Get an ArrayList for all events asssociated with this element in the datastor.<br><br>Caller owns the List and must `deinit()` after use |
| table.getEventsForBetween(id: usize, from, to: i64) ArrayList(EventT) | Get an ArrayList of all events for element matching ID, between to 2 timestamps.<br><br>Caller owns the list and must `deinit()` after use |
| | |
| table.addEvent(event)                       | Add the given event to the collection. Will append to disk as well as update the events in memory |
| table.latestEvent(id: usize)               | Get the latest event for element matching ID |
| table.eventAt(id: usize, timestamp: i64)   | Get the state of the element matching ID at the given timestamp. Will return the event that is on or before the given timestamp |


## Tree / Heirachy Table Support

In order to be treated as a tree, elements of the Table must have a field `parent_id: usize`

For Tagged Union types, the tagged union must provide 2 functions `getParentID() usize` and `setParentID(usize)` 

| Function | Description |
|----------|-------------|
| getChildren(parent_id) ArrayList(T) | Returns an ArrayList(T) of child nodes with this parent.<br><br>Caller owns the ArrayList and must `deinit()` after use |

---
# Table data Examples

## Define a Cat struct that can be used as a Datastor

```zig
const Cat = struct {
    id: usize = 0,
    breed: []const u8,
    color: []const u8,
    length: u16,
    aggression: f32,

    const Self = @This();

    // struct must supply a free() function for the datastor to manage cleaning up memory allocations
    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.breed);
        allocator.free(self.color);
    }
}
```

## Load a Datastor based on our Cat struct

```zig
pub fn load_simple_table() !void {
    const gpa = std.heap.page_allocator;

    var catDB = try datastor.Table(Cat).init(gpa, "db/cats.db");
    defer catDB.deinit();
    try catDB.load();

    // print out all the cats 
    for (catDB.items() |cat| {
        std.debug.print("Cat {d} is a {s} {s}, that is {d} inches long, with an aggression rating of {:.2f}\n", .{
            cat.id,
            cat.color,
            cat.breed,
            cat.length,
            cat.aggression,
        });
    }

    // update one of the cats to be more aggressive, and save the datastor
    var my_cat = catDB.get(2) orelse return;
    my_cat.aggression += 0.1;
    catDB.put(my_cat);
    catDB.save();
}
```

produces output:
```zig
Cat 0 is ID: 1 Breed: Siamese Color: white Length: 30, Aggression Factor: 7.00e-01
Cat 1 is ID: 2 Breed: Burmese Color: grey Length: 24, Aggression Factor: 6.00e-01
Cat 2 is ID: 3 Breed: Tabby Color: striped Length: 32, Aggression Factor: 5.00e-01
Cat 3 is ID: 4 Breed: Bengal Color: tiger stripes Length: 40, Aggression Factor: 9.00e-01
```

--- 

# Timeseries data Examples

So far so good. Our virtural world is now populated with a group of cats.

However, our cats (when they are not sleeping), like to get up and move around.

We need to track where are cats are and what they are doing.

But we dont want to have to keep overwritting state information against our Cats everytime something happens.

We can get around this by adding Timeseries data to each Cat. Timeseries data is a fast append-only, timestamped record
of events that tracks what happens with a Cat at a point in time.

Using a Timeseries log, we keep the original state information about all our cats in a pristine condition, and can use
the timeseries data to quickly work out what state any Cat is in at a point in time.

## Example - define Timeseries / Event data for each Cat

```zig
// A timeseries record of events that are associated with a cat
const CatEvent = struct {
    parent_id: usize = 0, // parent_id is the ID of the Cat that this event belongs to
    timestamp: i64,
    x: u16,
    y: u16,
    attacks: bool,
    kills: bool,
    sleep: bool,
    description: []const u8,

    const Self = @This();

    // events struct must also supply a free() function for the datastor to manage cleaning up memory allocations
    // since the event contains a string "description" that is allocated on demand.
    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }
}
```

## Example - Load Cats+Timeseries data, and run several different reports

```zig
pub fn cats_with_timeseries_data() !void {
    const gpa = std.heap.page_allocator;

    // use TableWithTimeseries - give it 2 struct types
    // one for the static info on the Cat, and the other to store events
    var catDB = try datastor.TableWithTimeseries(Cat, CatEvent).init(
      gpa,
      "db/cats.db",
      "db/cats.events",
    );
    defer catDB.deinit();

    // load both the base table, and all the events for all cats
    try catDB.load();

    // print out all the events in timestamp order
    std.debug.print("All events for all cats in timestamp order:\n", .{});
    for (catDB.getAllEvents()) |event| {
        std.debug.print("{s}", .{event});
    }

    // now print out Cats in the datastor,
    // along with an audit trail of events for each cat
    std.debug.print("\nAll cats with full audit trail:\n", .{});
    for (catDB.items()) |cat| {
        std.debug.print("Cat {s}\n", .{cat});
        const events = try catDB.getEventsFor(cat.id);
        defer events.deinit();
        for (events.items) |event| {
            std.debug.print("  - At {d}: {s} -> moves to ({d},{d}) status: (Asleep:{any}, Attacking:{any})\n",
            .{
               event.timestamp, event.description,
               event.x, event.y,
               event.sleep, event.attacks,
            });
        }
    }

    // iterate through 4 timestamps and show the state of all cats at the given timestamp
    for (0..4) |i| {
        const t = i * 10 + 1;
        std.debug.print("\nState of all cats at Timestamp {d}\n", .{t});
        for (catDB.items()) |cat| {
            if (catDB.eventAt(cat.id, @intCast(t))) |e| {
                std.debug.print("  - {s} {s} since {d} at ({d},{d}) status: (Asleep: {any}, Attacking: {any})\n",
                .{
                  cat.breed,
                  e.description,
                  e.timestamp,
                  e.x, e.y,
                  e.sleep,
                  e.attacks,
                });
            } else unreachable;
        }
    }

    // get the latest status for each cat
    std.debug.print("\nCurrent state of all cats, based on latest event for each\n", .{});
    for (catDB.items()) |cat| {
        const e = catDB.latestEvent(cat.id).?;
        std.debug.print("  - {s} is currently doing - {s} since {d} at ({d},{d}) status: (Asleep: {any}, Attacking: {any})\n",
            .{
                cat.breed,
                e.description,
                e.timestamp,
                e.x, e.y,
                e.sleep,
                e.attacks,
            });
    }
}
```

produces output :
```zig
ParentID: 1 Timestamp: 1 At 10,10  Attacks: false Kills false Sleeps true Comment: starts at Location
ParentID: 2 Timestamp: 1 At 20,10  Attacks: false Kills false Sleeps true Comment: starts at Location
ParentID: 3 Timestamp: 1 At 10,20  Attacks: false Kills false Sleeps true Comment: starts at Location
ParentID: 4 Timestamp: 1 At 20,20  Attacks: false Kills false Sleeps true Comment: starts at Location
ParentID: 1 Timestamp: 10 At 10,10  Attacks: false Kills false Sleeps false Comment: awakes
ParentID: 1 Timestamp: 20 At 20,10  Attacks: true Kills false Sleeps false Comment: attacks Burmese
ParentID: 2 Timestamp: 21 At 20,10  Attacks: false Kills false Sleeps false Comment: awakes
ParentID: 3 Timestamp: 21 At 10,20  Attacks: false Kills false Sleeps false Comment: awakes
ParentID: 2 Timestamp: 25 At 20,10  Attacks: true Kills false Sleeps false Comment: retaliates against Siamese
ParentID: 3 Timestamp: 29 At 10,20  Attacks: false Kills false Sleeps true Comment: goes back to sleep
ParentID: 4 Timestamp: 30 At 20,20  Attacks: false Kills false Sleeps false Comment: awakes from all the commotion
ParentID: 4 Timestamp: 40 At 20,10  Attacks: true Kills false Sleeps false Comment: attacks Burmese and Siamese

All cats with full audit trail:
Cat ID: 1 Breed: Siamese Color: white Length: 30, Aggression Factor: 7.00e-01
  - At 1: starts at Location -> moves to (10,10) status: (Asleep:true, Attacking:false)
  - At 10: awakes -> moves to (10,10) status: (Asleep:false, Attacking:false)
  - At 20: attacks Burmese -> moves to (20,10) status: (Asleep:false, Attacking:true)
Cat ID: 2 Breed: Burmese Color: grey Length: 24, Aggression Factor: 6.00e-01
  - At 1: starts at Location -> moves to (20,10) status: (Asleep:true, Attacking:false)
  - At 21: awakes -> moves to (20,10) status: (Asleep:false, Attacking:false)
  - At 25: retaliates against Siamese -> moves to (20,10) status: (Asleep:false, Attacking:true)
Cat ID: 3 Breed: Tabby Color: striped Length: 32, Aggression Factor: 5.00e-01
  - At 1: starts at Location -> moves to (10,20) status: (Asleep:true, Attacking:false)
  - At 21: awakes -> moves to (10,20) status: (Asleep:false, Attacking:false)
  - At 29: goes back to sleep -> moves to (10,20) status: (Asleep:true, Attacking:false)
Cat ID: 4 Breed: Bengal Color: tiger stripes Length: 40, Aggression Factor: 9.00e-01
  - At 1: starts at Location -> moves to (20,20) status: (Asleep:true, Attacking:false)
  - At 30: awakes from all the commotion -> moves to (20,20) status: (Asleep:false, Attacking:false)
  - At 40: attacks Burmese and Siamese -> moves to (20,10) status: (Asleep:false, Attacking:true)

State of all cats at Timestamp 1
  - Siamese starts at Location since 1 at (10,10) status: (Asleep: true, Attacking: false)
  - Burmese starts at Location since 1 at (20,10) status: (Asleep: true, Attacking: false)
  - Tabby starts at Location since 1 at (10,20) status: (Asleep: true, Attacking: false)
  - Bengal starts at Location since 1 at (20,20) status: (Asleep: true, Attacking: false)

State of all cats at Timestamp 11
  - Siamese awakes since 10 at (10,10) status: (Asleep: false, Attacking: false)
  - Burmese starts at Location since 1 at (20,10) status: (Asleep: true, Attacking: false)
  - Tabby starts at Location since 1 at (10,20) status: (Asleep: true, Attacking: false)
  - Bengal starts at Location since 1 at (20,20) status: (Asleep: true, Attacking: false)

State of all cats at Timestamp 21
  - Siamese attacks Burmese since 20 at (20,10) status: (Asleep: false, Attacking: true)
  - Burmese awakes since 21 at (20,10) status: (Asleep: false, Attacking: false)
  - Tabby awakes since 21 at (10,20) status: (Asleep: false, Attacking: false)
  - Bengal starts at Location since 1 at (20,20) status: (Asleep: true, Attacking: false)

State of all cats at Timestamp 31
  - Siamese attacks Burmese since 20 at (20,10) status: (Asleep: false, Attacking: true)
  - Burmese retaliates against Siamese since 25 at (20,10) status: (Asleep: false, Attacking: true)
  - Tabby goes back to sleep since 29 at (10,20) status: (Asleep: true, Attacking: false)
  - Bengal awakes from all the commotion since 30 at (20,20) status: (Asleep: false, Attacking: false)

Current state of all cats, based on latest event for each
  - Siamese is currently doing - attacks Burmese since 20 at (20,10) status: (Asleep: false, Attacking: true)
  - Burmese is currently doing - retaliates against Siamese since 25 at (20,10) status: (Asleep: false, Attacking: true)
  - Tabby is currently doing - goes back to sleep since 29 at (10,20) status: (Asleep: true, Attacking: false)
  - Bengal is currently doing - attacks Burmese and Siamese since 40 at (20,10) status: (Asleep: false, Attacking: true)
```

---

# Union Datatype Example

## Define a Union that can be used in a datastor

```zig
const AnimalType = enum { cat, dog };

const Animal = union(AnimalType) {
    const Self = @This();

    cat: cats.Cat,
    dog: dogs.Dog,

    // Union types MUST have ID getters and setters for now
    // bit annoying, but Im not sure yet how to get around this
    pub fn setID(self: *Self, id: usize) void {
        switch (self.*) {
            .cat => |*cat| cat.id = id,
            .dog => |*dog| dog.id = id,
        }
    }
    pub fn getID(self: Self) usize {
        switch (self) {
            .cat => |cat| return cat.id,
            .dog => |dog| return dog.id,
        }
    }

    pub fn free(self: Self, allocator: Allocator) void {
        switch (self) {
            .cat => |cat| cat.free(allocator),
            .dog => |dog| dog.free(allocator),
        }
    }
};
```

## Save data to a Union datastor

```zig
pub fn createTable() !void {
    const gpa = std.heap.page_allocator;
    var animalDB = try datastor.Table(Animal).init(gpa, "db/animals.db");
    defer animalDB.deinit();

    // add a cat
    try animalDB.append(Animal{
        .cat = .{
            // NOTE - we dupe these items onto the heap, because we want these strings 
            // to live beyond the scope of just this function
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

    try animalDB.save();
}

```

## Load Union data from a datastor

```zig
pub fn loadTable() !void {
    const gpa = std.heap.page_allocator;
    var animalDB = try datastor.Table(Animal).init(gpa, "db/animals.db");
    defer animalDB.deinit();

    try animalDB.load();
    for (animalDB.items(), 0..) |animal, i| {
        std.debug.print("Animal {d} is {any}:\n", .{ i, animal });
    }
}
```

produces output

```zig
Animal 0 is animals.Animal{ .cat = ID: 1 Breed: Siamese Color: Sliver Length: 28, Aggression Factor: 9.00e-01 }:
Animal 1 is animals.Animal{ .dog = ID: 2 Breed: Colley Color: Black and White Height: 33, Appetite: 9.00e-01 }:
```

---

# Tree / Heirachical Data examples

## Define a complicated struct that also represents Tree structured data

```zig
////////////////////////////////////////////////////////////////////////////////
// 3 types of things we can find in the forrest

const Tree = struct {
    id: usize = 0,
    parent_id: usize,
    x: u8, y: u8, height: u8,
};

const Creature = struct {
    const Self = @This();
    id: usize = 0,
    parent_id: usize,
    x: u8, y: u8, name: []const u8, weight: u8,

    // needs a free() function because it has a slice that gets allocated
    pub fn free(self: Self, allocator: Allocator) void {
        allocator.free(self.name);
    }
};

const Rock = struct {
    id: usize = 0,
    parent_id: usize,
    x: u8, y: u8, width: u8,
};

const ForrestInhabitantType = enum { tree, creature, rock };

const Forrest = union(ForrestInhabitantType) {
    const Self = @This();
    tree: Tree,
    creature: Creature,
    rock: Rock,

    // need these boilerplate functions to be able to act as datastor over this union type
    pub fn setID(self: *Self, id: usize) void {
        switch (self.*) {
            .tree => |*tree| tree.id = id,
            .creature => |*creature| creature.id = id,
            .rock => |*rock| rock.id = id,
        }
    }

    pub fn getID(self: Self) usize {
        switch (self) {
            .tree => |tree| return tree.id,
            .creature => |creature| return creature.id,
            .rock => |rock| return rock.id,
        }
    }

    pub fn free(self: Self, allocator: Allocator) void {
        switch (self) {
            .creature => |creature| creature.free(allocator),
            // only creatures need to be freed
            else => {},
        }
    }

    // adding these functions allows our forrest to act as a heirachy of nodes
    pub fn setParentID(self: *Self, id: usize) void {
        switch (self.*) {
            .tree => |*tree| tree.parent_id = id,
            .creature => |*creature| creature.parent_id = id,
            .rock => |*rock| rock.parent_id = id,
        }
    }

    pub fn getParentID(self: Self) usize {
        switch (self) {
            .tree => |tree| return tree.parent_id,
            .creature => |creature| return creature.parent_id,
            .rock => |rock| return rock.parent_id,
        }
    }
};


```

## Add some data to the Forrest Datastor

```zig
pub fn createTable() !void {
    const gpa = std.heap.page_allocator;

    var forrestDB = try datastor.Table(Forrest).init(gpa, "db/forrest.db");
    defer forrestDB.deinit();

    const root_id = try forrestDB.append(.{ .tree = .{ .parent_id = 0, .x = 10, .y = 10, .height = 10 } });
    {
        const pine_tree = try forrestDB.append(.{ .tree = .{ .parent_id = root_id, .x = 15, .y = 12, .height = 8 } });
        {
            _ = try forrestDB.append(.{ .creature = .{
                .parent_id = pine_tree,
                .x = 15,
                .y = 12,
                .name = try gpa.dupe(u8, "Squirrel"),
                .weight = 3,
            } });
            _ = try forrestDB.append(.{ .rock = .{ .parent_id = pine_tree, .x = 15, .y = 12, .width = 2 } });
        }
        const gum_tree = try forrestDB.append(.{ .tree = .{ .parent_id = root_id, .x = 8, .y = 12, .height = 6 } });
        {
            _ = try forrestDB.append(.{ .creature = .{
                .parent_id = gum_tree,
                .x = 8,
                .y = 12,
                .name = try gpa.dupe(u8, "Koala"),
                .weight = 10,
            } });
            _ = try forrestDB.append(.{ .creature = .{
                .parent_id = gum_tree,
                .x = 8,
                .y = 12,
                .name = try gpa.dupe(u8, "Kangaroo"),
                .weight = 20,
            } });
        }
        const weed = try forrestDB.append(.{ .tree = .{ .parent_id = root_id, .x = 5, .y = 5, .height = 2 } });
        {
            const moss_rock = try forrestDB.append(.{ .rock = .{ .parent_id = weed, .x = 5, .y = 6, .width = 2 } });
            {
                _ = try forrestDB.append(.{ .creature = .{
                    .parent_id = moss_rock,
                    .x = 5,
                    .y = 6,
                    .name = try gpa.dupe(u8, "Ant"),
                    .weight = 1,
                } });
                _ = try forrestDB.append(.{ .creature = .{
                    .parent_id = moss_rock,
                    .x = 5,
                    .y = 6,
                    .name = try gpa.dupe(u8, "Wasp"),
                    .weight = 1,
                } });
            }
        }
    }

    try forrestDB.save();
}
```

## Load and display Tree structured data using recursion

```zig

const ForrestDB = datastor.Table(Forrest);

pub fn loadTable() !void {
    const gpa = std.heap.page_allocator;
    var forrestDB = try ForrestDB.init(gpa, "db/forrest.db");
    defer forrestDB.deinit();

    try forrestDB.load();

    std.debug.print("Structured display for the contents of the forrest:\n\n", .{});
    try printForrestRecursive(forrestDB, 0, 0);
}

fn printForrestRecursive(forrestDB: ForrestDB, parent_id: usize, nesting: usize) !void {
    const children = try forrestDB.getChildren(parent_id);
    defer children.deinit();
    for (children.items) |forrest| {
        for (0..nesting) |_| {
            std.debug.print("    ", .{});
        }
        std.debug.print(" {}:\n", .{forrest});
        try printForrestRecursive(forrestDB, forrest.getID(), nesting + 1);
    }
}

```

produces output :

```zig
Structured display for the contents of the forrest:

 forrest.Forrest{ .tree = forrest.Tree{ .id = 1, .parent_id = 0, .x = 10, .y = 10, .height = 10 } }:
     forrest.Forrest{ .tree = forrest.Tree{ .id = 2, .parent_id = 1, .x = 15, .y = 12, .height = 8 } }:
         forrest.Forrest{ .creature = .id = 3, .parent_id = 2, .x = 15, .y = 12, .name = Squirrel, .weight = 3 }:
         forrest.Forrest{ .rock = forrest.Rock{ .id = 4, .parent_id = 2, .x = 15, .y = 12, .width = 2 } }:
     forrest.Forrest{ .tree = forrest.Tree{ .id = 5, .parent_id = 1, .x = 8, .y = 12, .height = 6 } }:
         forrest.Forrest{ .creature = .id = 6, .parent_id = 5, .x = 8, .y = 12, .name = Koala, .weight = 10 }:
         forrest.Forrest{ .creature = .id = 7, .parent_id = 5, .x = 8, .y = 12, .name = Kangaroo, .weight = 20 }:
     forrest.Forrest{ .tree = forrest.Tree{ .id = 8, .parent_id = 1, .x = 5, .y = 5, .height = 2 } }:
         forrest.Forrest{ .rock = forrest.Rock{ .id = 9, .parent_id = 8, .x = 5, .y = 6, .width = 2 } }:
             forrest.Forrest{ .creature = .id = 10, .parent_id = 9, .x = 5, .y = 6, .name = Ant, .weight = 1 }:
             forrest.Forrest{ .creature = .id = 11, .parent_id = 9, .x = 5, .y = 6, .name = Wasp, .weight = 1 }:
```

Please note that in this example of loading and displaying a Heirachy, there is no thrashing of the Datastor 
to look up sub-queries of sub-queries from disk.

There is a single Disk I/O operation up front to load the entire Tree into memory, and then all the subsequent
calls to get the children of a node are just run against the in-memory tree.

This is fine (and super fast) for Tree data that remains relatively static.

---

# Performance

err ... Im not going to post benchmarks with the tiny amount of data I have here, no point.
Keep in mind that disk IO occurs once at startup to load the data, and once every time a new event is added.

All data lookups are from memory only, so expect them to be quick. 

Static data is indexed through the hashMap key, and timeseries event data is not indexed at all, just appended always in timestamp order. Therefore all event lookups are full table scans.

This should be fine for timeseries data up to ... 10k records before it starts melting down  ? (dont know, just guessing)

Anything under 1000 records though, a full list scan is probably about as fast as a hashMap lookup anyway. (dont know, havnt measured yet)

For the record though ....

On a Mac M2 Pro, to create the Cats database, and timeseries events, insert all the records above, and save the data to disk = approx 1.5ms

Once the DB is created, running all the above queries, to:
- generate a list of all events for all cats
- generate a report of for each cat, show full audit trail
- step through 4 different timestamps, and print the status of each cat at that point in time
- then for all cats, show the current status based on  the last event

total query time for all that = approx 30us (microseconds)  or 0.03ms

----

## TODO List / Future Goals 

- Be able to change the type of the ID field from `usize` to - anything.
- Add automatic UUID stamps for all entities
- Add the ability to pass functions so you can do `map/filter/reduce` type ops on the Datastor contents
- Add something like a `datastor.zig.zon` file in a directory to allow some logical grouping of datastors into a larger DB schema
- Data version management & migration updates 
- Be able to load and save objects in S2S binary format to HTTP endpoints / S3 style cloud storage 
- Add the ability to attach Middleware to datastors.  Idea is something like - register a callback to fire when a table is updated or a new event is added.
- Add the ability to register clients that subscribe to event updates for a given record - needs that middleware function above.
- Add the abliity to register user defined serializers on a per-user-struct basis (ie - if `serialize()` exists on the struct, then use it)
- Ability to shard datastors that may get very large
- Import / Export to and from Excel / CSV / JSON formats
- Add multiple nodes, with replication and failover
- Add option to use protobuf format as the serialization format

## Future Goals - UI support

This comes in 2 parts.

Part 1 is having these as library functions that you can add to your app that does :

- Add a web based Datastor viewer (Zig app that spawns a local web server + HTMX app to navigate through stores, render datastor contents, etc)
- Add a  Native UI app (Zig app using libui-ng tables)

Part 2 is having a generic standalone program that does the same thing with existing datastor files.

Part 1 is easy, because your app code already has the structs defined in code. Part 2 is going to be hard, as S2S provides no schema info.
Will have to sort that problem out first

