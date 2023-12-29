# datastor.zig

Fast & Light Data persistence layer for Zig

Intended use is for:

- Object persistence in a typical game world setting
- A fast local data storage and retrieval system for edge / IoT devices
- Direct disk I/O, no need to talk to a DB server over the wire
- Thread safe for use in a single process
- Optimized for both Static and Timeseries data
- Static data that may be updated on rare occassions
- Situations where using an external DB are definitely overkill

Not intended for :

- Scalable, multi-process database backends.
- General Purpose data persistence. Datastor has a highly opinionated approach to dealing with Static vs Timeseries data. That may not suit the way your data is structured.
- Current data format uses native `usize` quite a bit, so the datafiles are not 100% portable between machines with different word sizes.
- Static datasets that grow, shrink, or change often.


On disk format uses S2S format for object storage
(see https://github.com/ziglibs/s2s)

S2S is battle tested code, but it does lack a few types that it can serialize out of the box. You can code around this
easy enough, but its something you should be aware of.


## *** DANGER ZONE ***

This code - and this README, are purely speculative at this point.

I will be rewriting the README a dozen times, as the API evolves, and code starts to work.

Feel free to follow along of course ... but its going to take time before I can post anything useful on this.

## Version Log

- Dec 2023 - v0.0.0 - init project
- Jan 2024 - v0.1.0 - TBD


## Project Scope - What it does

Datastor.zig provides an embedded "Object Persistence" API for collections of Zig Types.

No external DB dependencies, and no DLLs needed.

In concept, A Datastor is a light comptime wrapper around your struct, that provides :

- An ordered HashMap collection of elements, with a numeric SERIAL id
- Be able to insert records, and autoincrement the id if needed
- Functions to load / save that collection to and from disk
- An unlimited ArrayList of Timeseries events associated with each element in the collection
- Timeseries handy functions to get element state at a point in time / events over a period, etc
- Automatic synch to disk as your collection data changes
- Handles memory management nicely, so you can load / save / re-load data as much as you like, and let the library manage the allocations and frees
- Handles Tree structured data, so you can optionally overlay a heirachy on top of your collection (using a parent_id field)

## Missing Features / Future Goals 

- Be able to change the type of the ID field from `usize` to - anything.
- Add automatic UUID stamps for all entities
- Add the ability to pass functions so you can do `map/filter/reduce` type ops on the Datastor contents
- Add something like a `datastor.zig.zon` file in a directory to allow some logical grouping of datastors into a larger DB schema
- Data version management & migration updates 
- Be able to load and save objects in S2S binary format to HTTP endpoints / S3 style cloud storage 
- Add the ability to register clients that subscribe to event updates for a given record - need async / channels first though ??
- Add the abliity to register user defined serializers on a per-user-struct basis (ie - if `serialize()` exists on the struct, then use it)
- Ability to shard datastors that may get very large
- Import / Export to and from Excel / CSV / JSON formats
- Add multiple nodes, with replication and failover

## Future Goals - UI support

- Add a generic web based Datastor viewer (Zig app that spawns a local web server - navigate through stores, render datastor contents, etc)
- Add a generic Native UI app (Zig app using libui-ng tables)

## Intial State information vs State Transitions

Datastor takes a highly opinionated approach to separating data persistence between "Static" data, and "Timeseries" data.

Static data is for :
- TODO list of attributes of static data
- Static data is explicitly loaded and saved to and from disk using functions `table.load()` and `table.save()`

Timeseries data is for :
- TODO list of attributes of timeseries data
- Timeseries data is explicitly loaded on `table.load()`, and automatically appended to disk on `table.addEvent(Event)`


The API considers that the initial state of an Item, and its collection of events over time, form a single Coherent Entity with a single logical API.

On disk, its splits these into 2 files - 1 file for the initial Static data, that is rarely (if ever) updated, and 1 other file for the timeseries / event 
data, that is frequently appended to.

The Datastor API then wraps this as a single storage item.

## API Overview

For Static-only data :

| Function | Description |
|----------|-------------|
| Table(comptime T:type) |  Returns a Table object that wraps a collection of (struct) T<br><br>T must have a field named `id:usize` that uniquely identifies the record<br>T must have a function `free()` if it contains fields that are allocated on load (such as strings) | 
| table.init(Allocator, filename: []const u8) | Initialises the Table |
| table.deinit()                              | Free any memory resources consumed by the Table |
| | |
| table.load() !void                          | Explicitly load the collection from disk |
| table.save() !void                          | Explicitly save the data to disk |
| | |
| table.values() []T                          | Returns a slice of all the values in the Table |
| table.get(id) ?T                           | Gets the element of type T, with the given ID (or null if not found) |
| | |
| table.append(T)                             | Appends new element of type T to the Table. Does not write to disk yet. Batch up many updates, then call `save()` once | 
| table.put(T)                                | Add or overwrite element of type T to the Table. Does not write to disk yet. Batch up many updates, then call `save()` once | 
| table.appendAutoIncrement(T)                | Appends new element of type T to the Table, setting the ID of the element to the next in sequence. Does not write to disk yet | 

For Static + Timeseries data :

| Function | Description |
|----------|-------------|
| TableWithTimeseries(comptime T:type, comptime EventT: type) |  Returns a Table object that wraps a collection of (struct) T, with an unlimited array of EventT events attached<br><br>T must have a field named `id:usize` that uniquely identifies the record<br>T must have a function `free()` if it contains fields that are allocated on load (such as strings)<br><br>EventT must have a field named `parent_id:usize` and `timestamp:i64` | 
| table.init(Allocator, table_filename: []const u8, event_filename: []const u8) | Initialises the Table  |
| table.deinit()                              | Free any memory resources consumed by the Table |
| | |
| table.load() !void                          | Explicitly load the collection from disk |
| table.save() !void                          | Explicitly save the data to disk |
| | |
| table.values() []T                          | Returns a slice of all the values in the Table |
| table.get(id) ?T                           | Gets the element of type T, with the given ID (or null if not found) |
| | |
| table.append(T)                             | Appends new element of type T to the Table. Does not write to disk yet. Batch up many updates, then call `save()` once | 
| table.put(T)                                | Add or overwrite element of type T to the Table. Does not write to disk yet. Batch up many updates, then call `save()` once | 
| table.appendAutoIncrement(T)                | Appends new element of type T to the Table, setting the ID of the element to the next in sequence. Does not write to disk yet | 
| | |
| table.eventCount() usize                    | How many events all up ? |
| table.eventCountFor(id: usize) usize       | How many events for the given element ?|
| | |
| table.getAllEvents() []EventT               | Get all the events for all elements in this datastor, in timestamp order |
| table.getEventsBetween(from, to: i64) ArrayList(EventT) | Get an ArrayList of all events between to 2 timestamps. Caller owns the list and must `deinit()` after use |
| table.getEventsFor(id: usize) ArrayList(EventT) | Get an ArrayList for all events asssociated with this element in the datastor. Caller owns the List and must `deinit()` after use |
| table.getEventsForBetween(id: usize, from, to: i64) ArrayList(EventT) | Get an ArrayList of all events for element matching ID, between to 2 timestamps. Caller owns the list and must `deinit()` after use |
| | |
| table.addEvent(event)                       | Add the given event to the collection. Will append to disk as well as update the events in memory |
| table.latestEvent(id: usize)               | Get the latest event for element matching ID |
| table.eventAt(id: usize, timestamp: i64)   | Get the state of the element matching ID at the given timestamp. Will return the event that is on or before the given timestamp |
## Example - define a Cat struct that can be used as a Datastor

```
const Cat = struct {
    id: usize = 0,
    breed: []const u8,
    color: []const u8,
    length: u16,
    aggression: f32,

    const Self = @This();

    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.breed);
        allocator.free(self.color);
    }
}
```

## Example - Load a Datastor based on our Cat struct

```
pub fn load_simple_table() !void {
    const gpa = std.heap.page_allocator;

    var catDB = try datastor.Table(Cat).init(gpa, "db/cats.db");
    defer catDB.deinit();
    try catDB.load();

    // print out all the cats 
    for (catDB.values() |cat| {
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
```
Cat 0 is ID: 1 Breed: Siamese Color: white Length: 30, Aggression Factor: 7.00e-01
Cat 1 is ID: 2 Breed: Burmese Color: grey Length: 24, Aggression Factor: 6.00e-01
Cat 2 is ID: 3 Breed: Tabby Color: striped Length: 32, Aggression Factor: 5.00e-01
Cat 3 is ID: 4 Breed: Bengal Color: tiger stripes Length: 40, Aggression Factor: 9.00e-01
```

## Example - define Timeseries / Event data for each Cat

```
// A timeseries record of events that are associated with a cat
const CatEvent = struct {
    parent_id: usize = 0,
    timestamp: i64,
    x: u16,
    y: u16,
    attacks: bool,
    kills: bool,
    sleep: bool,
    description: []const u8,

    const Self = @This();

    pub fn free(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }
}
```

## Example - Load up a table of Cats, with embedded Timeseries data

```
pub fn cats_with_timeseries_data() !void {
    const gpa = std.heap.page_allocator;

    // use TableWithTimeseries - give it 2 struct types, one for the static info on the Cat, and the other to store events
    var catDB = try datastor.TableWithTimeseries(Cat, CatEvent).init(gpa, "db/cats.db", "db/cats.events");
    defer catDB.deinit();

    // load both the base table, and all the events for all cats
    try catDB.load();

    // print out all the events in timestamp order
    std.debug.print("All events for all cats in timestamp order:\n", .{});
    for (catDB.getAllEvents()) |event| {
        std.debug.print("{s}", .{event});
    }

    // now print out Cats in the datastor, along with an audit trail of events for each cat
    std.debug.print("\nAll cats with full audit trail:\n", .{});
    for (catDB.values()) |cat| {
        std.debug.print("Cat {s}\n", .{cat});
        const events = try catDB.getEventsFor(cat.id);
        for (events.items) |event| {
            std.debug.print("  - At {d}: {s} -> moves to ({d},{d}) status: (Asleep:{any}, Attacking:{any})\n", .{ event.timestamp, event.description, event.x, event.y, event.sleep, event.attacks });
        }
        defer events.deinit();
    }

    // iterate through 3 timestamps and show the state of all cats at the given timestamp
    for (0..4) |i| {
        const t: i64 = @as(i64, @intCast(i * 10 + 1));
        std.debug.print("\nState of all cats at Timestamp {d}\n", .{t});
        for (catDB.values()) |cat| {
            if (catDB.eventAt(cat.id, t)) |e| {
                std.debug.print("  - {s} {s} since {d} at ({d},{d}) status: (Asleep: {any}, Attacking: {any})\n", .{ cat.breed, e.description, e.timestamp, e.x, e.y, e.sleep, e.attacks });
            } else unreachable;
        }
    }

    // get the latest status for each cat
    std.debug.print("\nCurrent state of all cats, based on latest event for each\n", .{});
    for (catDB.values()) |cat| {
        const e = catDB.latestEvent(cat.id).?;
        std.debug.print("  - {s} is currently doing - {s} since {d} at ({d},{d}) status: (Asleep: {any}, Attacking: {any})\n", .{ cat.breed, e.description, e.timestamp, e.x, e.y, e.sleep, e.attacks });
    }
}
```

produces output :
```
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

## Performance

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





## Example Datastor Design

** TODO ** - delete or rewrite this. Its getting obsolete too quick !

Its easiest to explain the use cases in terms of providing object persistence for a game world here ... but you can easily also imagine 
a similar usage for an IoT device that needs fast and efficient local storage.

Lets say we have a game world, where the world state has the following types of data :

|Datastor Name   | Description |
|----------------|-------------|
|Place           | A place in our world that has a name, (x,y) coordinates, and an amount of gold to be found there |
|Monster         | A monster in our world that has a name, (x,y) coordinates, attack value, number of hit points, amount of gold carried|
|Henchman        | An NPC henchman in our world that has a name, (x,y) coordinates, hit points, and a cost per day to hire|

So far so good, we can store each of these as a Datastor Table.

Now, with our Henchmen, the problem here that they operate in a heirachy of companies. A Captain of a band of 10 henchmen for example ... who may in turn
be a member of a Guild that employs many henchman.  We can model the Henchman datastor as a Tree in this case, allowing us to hire 1 henchman, or hire the captain
of a team of 10, or hire an entire guild if we can afford it.

Next problem we have is (x,y) coordinate locations, and hit points.

The (x,y) coordinates of a 'Place' remains static throughout the game, so thats fine. 

However, each monster may move around randomly in our game world, and its hit-points may go up and down as it gets involved in various activities.
Likewise with our Henchmen, they move around, their hit-points change, and they can move in and out of availablity as they get hired by other players in our game world.

We need to track all these changes to both Monsters and Henchmen, so we add 2 Timeseries datastors to track state changes :

|Datastor Name     | Description |
|------------------|-------------|
| Monster.events   | Monster ID, Turn Number, (x,y) coordinates, hit-points, gold | 
| Henchman.events  | Henchman ID, Turn Number, (x,y) coordinates, hit-points, hired status |


So now, for every Monster in our game world, we have 1 static record in the "Monster" datastor that gives us the monster's starting stats, and 1 array of records
in the Monster.Tracking timeseries datastor, linked to this Monster that provides a detailed turn-by turn audit trail of state changes to the monster as it moves
around our world, takes damage, and accumulates gold.

The Henchman case is a bit more subtle.

In the Henchman datastor tree, we may have hired the Captain of a band of 10 Brigands. However, each individual Henchman also has a single record in the Henchman datastor
with it's own unique ID. In the Henchman.Event table, every single Henchman has 1 array of turn-by-turn audit records.

