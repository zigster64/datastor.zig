# datastor.zig
Data persistence library for Zig

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
|Timeseries    | The datastor holds timeseries/audit trail info associated with changes to the state of a type | timestamp() -> returns a unique key to label this row. This could be a real timestamp, or it could be something like "turn number", etc |

## Column Types

## Installation and Usage

## API reference
