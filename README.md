# [WIP] Database project

As it stands, this is a toy project to better understand zig and databases in general.

This project is a loose implementation of a small embedded database, like sqlite or duckdb, but much worse.

# Requirements

Currently, I'm, using the zig master branch which is on version 0.16.0-dev.

I swapped to 0.16.0-dev so that we use the new Io implementations from the start.

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

`pager.zig` implements a pager. It can read, write, or allocate a page to a file.
`node.zig` implements some basic LEAF and INTERNAL node reading and writing.
`btree.zig` ties the pager and node together and handles the core work.
`main.zig` is mostly a placeholder as of writing this.


# Goals

- Learn zig better
- Implement Row and Column stores
- Implement basic SQL queries
