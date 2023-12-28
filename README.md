# datastor.zig

Fast & Light Data persistence layer for Zig

Intended use is for:

- Object persistence in a typical game world setting
- A fast local data storage and retrieval system for edge / IoT devices
- Direct disk I/O, no need to talk to a DB server over the wire
- Thread safe for use in a single process
- Optimized for both Static and Timeseries data

Not intended for :

- Scalable, multi-process database backends.
- General Purpose data persistence. Datastor has a highly opinionated approach to dealing with Static vs Timeseries data. That may not suit the way your data is structured.
- Current data format uses native `usize` quite a bit, so the datafiles are not 100% portable between machines with different word sizes.

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

- An ordered HashMap collection of elements, with a numeric SERIAL key
- Be able to insert records, and autoincrement the key if needed
- Functions to load / save that collection to and from disk
- An unlimited ArrayList of Timeseries events associated with each element in the collection
- Timeseries handy functions to get element state at a point in time / events over a period, etc
- Automatic synch to disk as your collection data changes
- Handles memory management nicely, so you can load / save / re-load data as much as you like, and let the library manage the allocations and frees
- Handles Tree structured data, so you can optionally overlay a heirachy on top of your collection (using a parent_key field)

## Missing Features / Future Goals 

- Be able to change the type of the KEY field from `usize` to - anything.
- Add automatic UUID stamps for all entities
- Add the ability to pass functions so you can do `map/filter/reduce` type ops on the Datastor contents
- Add something like a `datastor.zig.zon` file in a directory to allow some logical grouping of datastors into a larger DB schema
- Data version management & migration updates 
- Be able to load and save objects in S2S binary format to HTTP endpoints / S3 style cloud storage 
- Add the ability to register clients that subscribe to event updates for a given record - need async / channels first though ??
- Add the abliity to register user defined serializers on a per-user-struct basis (ie - if `serialize()` exists on the struct, then use it)
- Ability to shard datastors that may get very large
- Import / Export to and from Excel / CSV / JSON formats

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
| Table(comptime T:type) |  Returns a Table object that wraps a collection of (struct) T<br><br>T must have a field named `key:usize` that uniquely identifies the record<br>T must have a function `free()` if it contains fields that are allocated on load (such as strings) | 
| table.init(Allocator, filename: []const u8) | Initialises the Table |
| table.deinit()                              | Free any memory resources consumed by the Table |
| | |
| table.load() !void                          | Explicitly load the collection from disk |
| table.save() !void                          | Explicitly save the data to disk |
| | |
| table.values() []T                          | Returns a slice of all the values in the Table |
| table.get(key) ?T                           | Gets the element of type T, with the given KEY (or null if not found) |
| | |
| table.append(T)                             | Appends new element of type T to the Table. Does not write to disk yet | 
| table.appendAutoIncrement(T)                | Appends new element of type T to the Table, setting the KEY of the element to the next in sequence. Does not write to disk yet | 

For Static + Timeseries data :

| Function | Description |
|----------|-------------|
| TableWithTimeseries(comptime T:type, comptime EventT: type) |  Returns a Table object that wraps a collection of (struct) T, with an unlimited array of EventT events attached<br><br>T must have a field named `key:usize` that uniquely identifies the record<br>T must have a function `free()` if it contains fields that are allocated on load (such as strings)<br><br>EventT must have a field named `parent_key:usize` and `timestamp:i64` | 
| table.init(Allocator, table_filename: []const u8, event_filename: []const u8) | Initialises the Table  |
| table.deinit()                              | Free any memory resources consumed by the Table |
| | |
| table.load() !void                          | Explicitly load the collection from disk |
| table.save() !void                          | Explicitly save the data to disk |
| | |
| table.values() []T                          | Returns a slice of all the values in the Table |
| table.get(key) ?T                           | Gets the element of type T, with the given KEY (or null if not found) |
| | |
| table.append(T)                             | Appends new element of type T to the Table. Does not write to disk yet | 
| table.appendAutoIncrement(T)                | Appends new element of type T to the Table, setting the KEY of the element to the next in sequence. Does not write to disk yet | 
| | |
| table.eventCount() usize                    | How many events all up ? |
| table.eventCountFor(key: usize) usize       | How many events for the given element ?|
| | |
| table.getAllEvents() []EventT               | Get all the events for all elements in this datastor, in timestamp order |
| table.getEventsBetween(from, to: i64) ArrayList(EventT) | Get an ArrayList of all events between to 2 timestamps. Caller owns the list and must `deinit()` after use |
| table.getEventsFor(key: usize) ArrayList(EventT) | Get an ArrayList for all events asssociated with this element in the datastor. Caller owns the List and must `deinit()` after use |
| table.getEventsForBetween(key: usize, from, to: i64) ArrayList(EventT) | Get an ArrayList of all events for element matching KEY, between to 2 timestamps. Caller owns the list and must `deinit()` after use |
| | |
| table.addEvent(event)                       | Add the given event to the collection. Will append to disk as well as update the events in memory |
| table.latestEvent(key: usize)               | Get the latest event for element matching KEY |
| table.eventAt(key: usize, timestamp: i64)   | Get the state of the element matching KEY at the given timestamp. Will return the event that is on or before the given timestamp |
## Example Datastor Design

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


## Design impacts on Data Retrieval

Now that our data is organised, as above, into Tables, Trees & Timeseries data ... lets have a look at what we can do, and how the code looks like

- Get information on a Place

```
// Define a struct to hold a Place
Place = struct {
  key: usize,
  name: []u8,
  x: u16,
  y: u16,
  gold: u16,

  pub fn free(self: @This(), allocator: Allocator) void {
    allocator.free(name);
  }
  
}

// Define a datastor of Places
places = datastor(Place).init(allocator, "data/places.db");

// Load the places datastor from disk
try places.load();

// Lookup the details of a place .. with ID 7
const place = try places.get(7);

// place is now filled in with the values for place 7
```

