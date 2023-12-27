# datastor.zig

Data persistence layer for Zig

Intended use is for:

- Object persistence in a typical game world setting
- A fast local data storage and retrieval system for edge / IoT devices

Datastor requires you to _provide your own serializer_ to read and write objects.

## DANGER ZONE

This code - and this README, are purely speculative at this point.

I will be rewriting the README a dozen times, as the API evolves, and code starts to work.

Feel free to follow along of course ... but its going to take time before I can post anything useful on this.


## What it does

Datastor.zig provides an "Object Persistence" API for collections of Types, as pure Zig code.

The Datastor is designed to be used for loading / saving application state information from disk into in-memory representations. 

You use this in your app, as Zig code, so your resultant executable has no runtime deps on any special DLLs or Database servers.

Each Datastor is the equivalent of a "Table" in an SQL database, and is backed by a single file on disk. Each row in the table holds 1 Zig type (which could be a simple value, or a struct)

Whilst Datastor can equate to a simple 2D table of rows and columns, it also has other forms :

|Datastor Type | Description | Type Requirements |
|--------------|-------------|-------------------|
|Table         | The datastor holds a simple 2D table of data with Rows and Columns | id() -> returns a unique ID for this value.<br>  write(Writer) -> will serialize the Type to the writer. <br>read(Reader) -> will deserialize the Type from the writer |
|Tree          | The datastor holds a tree structure of Types. | parent() -> returns the unique ID for the parent of this node in the tree. |
|Timeseries    | The datastor holds timeseries/audit trail info associated with changes to the state of a Table entry | timestamp() -> returns a unique key to label this row. This could be a real timestamp, or it could be something like "turn number", etc |

## Intial State information vs State Transitions

Unlike common datastores such as SQL ... Datastor distinguishes between initial (and static) State information, vs State Transitions over time.


## Performance Expectations and Design of your Data

On init, Datastor Table and Tree objects will read the entire file from disk, and create an in-memory, ordered HashMap of the data.

It is expected that your application will then use this in-memory representation once the data is loaded is from disk. Unlike - say SQL, where
the application makes a call to SELECT FROM TABLE everytime a lookup is needed.

On write, the entire Datastor Table or Tree is re-written to disk. Therefore, design your usage of this so that only static (or rarely updated) state information is held in 
a Table or Tree.

For state information that changes frequently, use the Timeseries Datastor to record updates to state. 

Each Timeseries Datastor is always associated with 1 static Table or Tree datastor. Use this to provide storage for any information that changes over time.

Timeseries Datator writes are fast, append-only updates that write 1 record at a time, and are suitable for persisting high frequency updates to state information.

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
  id: u8,
  name: []u8,
  x: u16,
  y: u16,
  gold: u16,
  
  pub fn id(self: @This()) u8 {
    return self.id;
  }

  // roll your own serializer !!
  pub fn write(self: @This(), writer: anytype) !void {
      .. serialize to writer
  }
  pub fn read(self: @This(), allocator: Allocator, reader: anytype) !void {
      .. deserialize from reader
  }
}

// Define a datastor of Places
places = datastor(Place).init(allocator, .{.Table, .Static}); 

// Load the places datastor from disk
try places.load("data/place");

// Lookup the details of a place .. with ID 7
const place = try places.get(7);

// place is now filled in with the values for place 7
```

- Get information on a Monster

```
// Define a struct to hold a Monster
Monster = struct {
  id: u8,
  name: []u8,
  x: u16,
  y: u16,
  attack_value: u16,
  hit_points: u16,
  gold: u16,
  events: []Event,
  const Self = @This();
  
  pub fn id(self: Self) u8 {
    return self.id;
  }

  // roll your own serializer !!
  pub fn write(self: Self, writer: anytype) !void {
      .. serialize to writer
  }
  pub fn read(self: Self, allocator: Allocator, reader: anytype) !void {
      .. deserialize from reader
  }
  pub fn event(self: Self) ?Event {
     .. return the most recernt event
  }
  pub fn addEvent(self: Self, event: Event) !void {
     .. add a new event to the arary of events
  }

  // define the timeseries events for each monster
  const Event = struct {
    turn: u16,
    x: u16,
    y: u16,
    hit_points: u16,
    gold: u16,

    // roll your own serializer !!
    pub fn write(self: @This(), writer: anytype) !void {
        .. serialize to writer
    }
    pub fn read(self: @This(), allocator: Allocator, reader: anytype) !void {
        .. deserialize from reader
    }
  }
}

// Define a datastor of Monsters
monsters = datastor(Monster).init(allocator, .{.Table, .Events}); 

// Load the monsters from disk
try monsters.load("data/monster");

// Lookup the details of a monster .. with ID 21
const place = try places.get(7);

// place is now filled in with the values for place 7
```

## Column Types

## Installation and Usage

## API reference
