# Database project

As it stands, this is a toy project to better understand zig and databases in general.

This project is a loose implementation of a small embedded database, like sqlite or duckdb, but much worse.


# Structure

```
.
├── btree_notes.md
├── build.zig
├── build.zig.zon
├── data
│   └── data.zdb
├── README.md
├── src
│   ├── btree.zig
│   ├── main.zig
│   ├── node.zig
│   └── pager.zig
└── zig-out (.gitignore)
```
