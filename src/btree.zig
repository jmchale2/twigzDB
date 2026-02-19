/// btree.zig
///
const std = @import("std");
const pager = @import("pager.zig");
const node = @import("node.zig");

const print = std.debug.print;

const TreeError = error{ AlreadyExists, PageFull, DuplicateKey };

const SearchResult = struct { index: u32, found: bool };

pub fn initTree(pgr: pager.Pager) !void {
    const page_count = try pgr.pageCount();

    if (page_count > 0) {
        print("Non-zero page count returning", .{});
        return TreeError.AlreadyExists;
    }
    const page_number = try pgr.allocatePage();

    var buf: [4096]u8 = undefined;
    try pgr.readPage(page_number, &buf);

    node.setNodeTypeHeader(&buf, .LEAF);

    try pgr.writePage(page_number, &buf);
}

test "init tree" {
    const io = std.testing.io;
    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_init.db", .{ .read = true });
    defer dir.deleteFile(io, "test_init.db") catch {};

    const page_size = 4096;
    const pgr = pager.Pager{ .file = file, .page_size = page_size, .io = io };

    try initTree(pgr);

    var buf: [page_size]u8 = undefined;
    try pgr.readPage(0, &buf);

    const page: [page_size]u8 = @splat(0);

    try std.testing.expectEqual(page, buf);
}

pub fn leafSearch(page_buf: []const u8, key: u32) !SearchResult {
    const n_cells = node.getCellCountHeader(page_buf);

    var low: u32 = 0;
    var high: u32 = n_cells;
    var mid: u32 = undefined;

    while (low < high) {
        mid = @divFloor(low + high, 2);

        const mid_key = node.getLeafCell(page_buf, mid).key;
        if (mid_key == key) {
            return .{ .index = mid, .found = true };
        } else if (mid_key < key) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    return .{ .index = low, .found = false };
}

test "tree search - all found" {

    //setup pager
    const io = std.testing.io;

    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_search.db", .{ .read = true });
    defer dir.deleteFile(io, "test_search.db") catch {};

    const page_size = 4096;
    var pgr = pager.Pager{ .file = file, .page_size = page_size, .io = io };

    const page_idx = try pgr.allocatePage();

    var ck_buf: [page_size]u8 = undefined;
    @memset(&ck_buf, 0);

    var page_buf: [page_size]u8 = undefined;
    try pgr.readPage(page_idx, &page_buf);
    // verify our pager has a page
    try std.testing.expectEqualSlices(u8, &ck_buf, &page_buf);

    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);

    node.setLeafCell(&page_buf, 0, .{ .key = 1, .value = @splat(1) });
    node.setLeafCell(&page_buf, 1, .{ .key = 5, .value = @splat(5) });
    node.setLeafCell(&page_buf, 2, .{ .key = 10, .value = @splat(10) });
    node.setLeafCell(&page_buf, 3, .{ .key = 15, .value = @splat(15) });
    node.setLeafCell(&page_buf, 4, .{ .key = 100, .value = @splat(100) });

    node.setCellCountHeader(&page_buf, 5);
    // write test page
    try pgr.writePage(page_idx, &page_buf);

    const cell_counter = node.getCellCountHeader(&page_buf);
    _ = cell_counter;

    // all values are found
    const values: [5]u32 = .{ 1, 5, 10, 15, 100 };
    const expected_results: [5]SearchResult = .{
        .{ .index = 0, .found = true },
        .{ .index = 1, .found = true },
        .{ .index = 2, .found = true },
        .{ .index = 3, .found = true },
        .{ .index = 4, .found = true },
    };
    var results: [5]SearchResult = undefined;
    for (values, 0..) |v, i| {
        results[i] = try leafSearch(&page_buf, v);
    }

    try std.testing.expectEqualSlices(SearchResult, &expected_results, &results);
}

test "tree search - none found" {

    //setup pager
    const io = std.testing.io;

    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_search.db", .{ .read = true });
    defer dir.deleteFile(io, "test_search.db") catch {};

    const page_size = 4096;
    var pgr = pager.Pager{ .file = file, .page_size = page_size, .io = io };

    const page_idx = try pgr.allocatePage();

    var ck_buf: [page_size]u8 = undefined;
    @memset(&ck_buf, 0);

    var page_buf: [page_size]u8 = undefined;
    try pgr.readPage(page_idx, &page_buf);
    // verify our pager has a page
    try std.testing.expectEqualSlices(u8, &ck_buf, &page_buf);

    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);

    node.setLeafCell(&page_buf, 0, .{ .key = 1, .value = @splat(1) });
    node.setLeafCell(&page_buf, 1, .{ .key = 5, .value = @splat(5) });
    node.setLeafCell(&page_buf, 2, .{ .key = 10, .value = @splat(10) });
    node.setLeafCell(&page_buf, 3, .{ .key = 15, .value = @splat(15) });
    node.setLeafCell(&page_buf, 4, .{ .key = 100, .value = @splat(100) });

    node.setCellCountHeader(&page_buf, 5);
    // write test page
    try pgr.writePage(page_idx, &page_buf);

    const cell_counter = node.getCellCountHeader(&page_buf);
    _ = cell_counter;

    // no values are found
    const values: [5]u32 = .{ 0, 7, 12, 17, 101 };
    const expected_results: [5]SearchResult = .{
        .{ .index = 0, .found = false },
        .{ .index = 2, .found = false },
        .{ .index = 3, .found = false },
        .{ .index = 4, .found = false },
        .{ .index = 5, .found = false },
    };
    var results: [5]SearchResult = undefined;
    for (values, 0..) |v, i| {
        results[i] = try leafSearch(&page_buf, v);
    }

    try std.testing.expectEqualSlices(SearchResult, &expected_results, &results);
}

test "tree search - no cells" {

    //setup pager
    const io = std.testing.io;

    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_search_empty.db", .{ .read = true });
    defer dir.deleteFile(io, "test_search_empty.db") catch {};

    const page_size = 4096;
    var pgr = pager.Pager{ .file = file, .page_size = page_size, .io = io };

    const page_idx = try pgr.allocatePage();

    var ck_buf: [page_size]u8 = undefined;
    @memset(&ck_buf, 0);

    var page_buf: [page_size]u8 = undefined;
    try pgr.readPage(page_idx, &page_buf);
    // verify our pager has a page
    try std.testing.expectEqualSlices(u8, &ck_buf, &page_buf);

    // no values are found
    const values: [5]u32 = .{ 0, 7, 12, 17, 101 };
    const expected_results: [5]SearchResult = .{
        .{ .index = 0, .found = false },
        .{ .index = 0, .found = false },
        .{ .index = 0, .found = false },
        .{ .index = 0, .found = false },
        .{ .index = 0, .found = false },
    };
    var results: [5]SearchResult = undefined;
    for (values, 0..) |v, i| {
        results[i] = try leafSearch(&page_buf, v);
    }

    try std.testing.expectEqualSlices(SearchResult, &expected_results, &results);
}

pub fn leafInsert(page_buf: []u8, cell: node.LeafCell) !void {
    const cell_count = node.getCellCountHeader(page_buf);
    if (cell_count == node.MAX_LEAF_CELLS) {
        return TreeError.PageFull;
    }

    const search_result = try leafSearch(page_buf, cell.key);
    if (search_result.found) return TreeError.DuplicateKey;

    const max_offset = node.getLeafOffset(cell_count);
    const search_idx = search_result.index;
    const cell_start_idx = node.getLeafOffset(search_idx);

    if (cell_start_idx < max_offset) {
        @memmove(page_buf[cell_start_idx + node.LEAF_CELL_SIZE .. max_offset + node.LEAF_CELL_SIZE], page_buf[cell_start_idx..max_offset]);
    }

    node.setLeafCell(page_buf, search_idx, cell);

    const new_cell_count = cell_count + 1;
    node.setCellCountHeader(page_buf, @as(u16, @intCast(new_cell_count)));
}

test "leaf insert one" {
    const page_size = 4096;
    var page_buf: [page_size]u8 = undefined;
    @memset(&page_buf, 0);
    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);

    try leafInsert(&page_buf, .{ .key = 1, .value = @splat(1) });

    const cell_counter = node.getCellCountHeader(&page_buf);
    try std.testing.expectEqual(1, cell_counter);

    const results = try leafSearch(&page_buf, 1);

    try std.testing.expectEqual(SearchResult{ .index = 0, .found = true }, results);

    const inserted_cell = node.getLeafCell(&page_buf, 0);

    try std.testing.expectEqual(node.LeafCell{ .key = 1, .value = @splat(1) }, inserted_cell);
}

test "leaf shift and insert one left" {
    const page_size = 4096;

    var page_buf: [page_size]u8 = undefined;
    @memset(&page_buf, 0);

    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);
    // insert one cell
    try leafInsert(&page_buf, .{ .key = 5, .value = @splat(5) });
    // insert a cell to the left
    try leafInsert(&page_buf, .{ .key = 1, .value = @splat(1) });

    const cell_counter = node.getCellCountHeader(&page_buf);
    try std.testing.expectEqual(2, cell_counter);

    // Check on LEFT value
    const results = try leafSearch(&page_buf, 1);

    try std.testing.expectEqual(SearchResult{ .index = 0, .found = true }, results);
    const inserted_cell = node.getLeafCell(&page_buf, 0);

    // Check on RIGHT value
    const right_results = try leafSearch(&page_buf, 5);
    try std.testing.expectEqual(SearchResult{ .index = 1, .found = true }, right_results);
    const right_inserted_cell = node.getLeafCell(&page_buf, 1);

    try std.testing.expectEqual(node.LeafCell{ .key = 1, .value = @splat(1) }, inserted_cell);
    try std.testing.expectEqual(node.LeafCell{ .key = 5, .value = @splat(5) }, right_inserted_cell);
}

test "leaf insert one right" {
    const page_size = 4096;

    var page_buf: [page_size]u8 = undefined;
    @memset(&page_buf, 0);

    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);
    // insert one cell
    try leafInsert(&page_buf, .{ .key = 1, .value = @splat(1) });
    // insert a cell to the right
    try leafInsert(&page_buf, .{ .key = 5, .value = @splat(5) });

    const cell_counter = node.getCellCountHeader(&page_buf);
    try std.testing.expectEqual(2, cell_counter);

    // Check on LEFT value
    const results = try leafSearch(&page_buf, 1);

    const right_results = try leafSearch(&page_buf, 5);

    try std.testing.expectEqual(SearchResult{ .index = 0, .found = true }, results);
    const inserted_cell = node.getLeafCell(&page_buf, 0);

    // Check on RIGHT value
    try std.testing.expectEqual(SearchResult{ .index = 1, .found = true }, right_results);
    const right_inserted_cell = node.getLeafCell(&page_buf, 1);

    try std.testing.expectEqual(node.LeafCell{ .key = 1, .value = @splat(1) }, inserted_cell);
    try std.testing.expectEqual(node.LeafCell{ .key = 5, .value = @splat(5) }, right_inserted_cell);
}

test "leaf insert many" {
    const page_size = 4096;
    var page_buf: [page_size]u8 = undefined;
    @memset(&page_buf, 0);
    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);

    var insert_cells: [7]node.LeafCell = .{
        .{ .key = 1, .value = @splat(1) },
        .{ .key = 3, .value = @splat(2) },
        .{ .key = 5, .value = @splat(3) },
        .{ .key = 15, .value = @splat(4) },
        .{ .key = 50, .value = @splat(5) },
        .{ .key = 80, .value = @splat(6) },
        .{ .key = 100, .value = @splat(7) },
    };

    var prng = std.Random.DefaultPrng.init(15);
    const rand = prng.random();
    rand.shuffle(node.LeafCell, &insert_cells);
    // print("Actual insertion order\n", .{});
    // for (insert_cells) |cell| {
    //     print("{d}\n", .{cell.key});
    // }
    //
    // Actual insertion order
    // 1
    // 80
    // 3
    // 50
    // 100
    // 5
    // 15

    const key_order: [7]u32 = .{ 1, 3, 5, 15, 50, 80, 100 };

    //insert cells
    for (insert_cells) |cell| {
        try leafInsert(&page_buf, cell);
    }

    var returned_keys: [7]u32 = undefined;
    for (key_order, 0..) |key, idx| {
        _ = key;
        returned_keys[idx] = node.getLeafCell(&page_buf, @as(u32, @intCast(idx))).key;
    }
    // print("{any}\n", .{returned_keys});

    try std.testing.expectEqualSlices(u32, &key_order, &returned_keys);
}

test "leaf insert - duplicate key" {
    const page_size = 4096;
    var page_buf: [page_size]u8 = undefined;
    @memset(&page_buf, 0);
    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);

    try leafInsert(&page_buf, .{ .key = 1, .value = @splat(1) });

    try std.testing.expectError(
        TreeError.DuplicateKey,
        leafInsert(&page_buf, .{ .key = 1, .value = @splat(1) }),
    );
}

test "leaf insert - page full" {
    const page_size = 4096;
    var page_buf: [page_size]u8 = undefined;
    @memset(&page_buf, 0);
    // populate cells
    node.setNodeTypeHeader(&page_buf, .LEAF);

    var i: u32 = 0;
    while (i < node.MAX_LEAF_CELLS) : (i += 1) {
        try leafInsert(&page_buf, .{ .key = i, .value = @splat(1) });
    }

    try std.testing.expectError(
        TreeError.PageFull,
        leafInsert(&page_buf, .{ .key = i + 1, .value = @splat(1) }),
    );
}

pub fn leafSplit(left_buf: []u8, right_buf: []u8) u32 {

    //do the thing
    const left_cell_count = node.getCellCountHeader(left_buf);
    const half_cells = @divFloor(left_cell_count, 2);

    const middle_offset = node.getLeafOffset(half_cells);
    const end_offset = node.getLeafOffset(left_cell_count);
    const new_offset = node.getLeafOffset(0);
    const new_end_offset = new_offset + end_offset - middle_offset;

    @memmove(right_buf[new_offset..new_end_offset], left_buf[middle_offset..end_offset]);
    @memset(left_buf[middle_offset..end_offset], 0);

    node.setCellCountHeader(left_buf, half_cells);
    node.setCellCountHeader(right_buf, left_cell_count - half_cells);

    const right_cell = node.getLeafCell(right_buf, 0);
    const right_lowest_key: u32 = right_cell.key;

    return right_lowest_key;
}

test "leaf split - base" {
    const page_size = 4096;
    var left_buf: [page_size]u8 = undefined;
    @memset(&left_buf, 0);

    node.setNodeTypeHeader(&left_buf, .LEAF);

    //fill left page
    var i: u32 = 0;
    while (i < node.MAX_LEAF_CELLS) : (i += 1) {
        try leafInsert(&left_buf, .{ .key = i, .value = @splat(1) });
    }

    // ensure page full would be returned
    try std.testing.expectError(
        TreeError.PageFull,
        leafInsert(&left_buf, .{ .key = i + 1, .value = @splat(1) }),
    );

    var right_buf: [page_size]u8 = undefined;
    @memset(&right_buf, 0);

    const initial_left_cell_count = node.getCellCountHeader(&left_buf);
    const half_cells = @divFloor(initial_left_cell_count, 2);
    const other_half_cells = initial_left_cell_count - half_cells;

    const new_key = leafSplit(&left_buf, &right_buf);

    const after_left_cell_count = node.getCellCountHeader(&left_buf);
    const after_right_cell_count = node.getCellCountHeader(&right_buf);

    try std.testing.expectEqual(new_key, 7);

    try std.testing.expectEqual(after_left_cell_count, half_cells);
    try std.testing.expectEqual(after_right_cell_count, other_half_cells);

    var left_cells: [7]node.LeafCell = undefined;
    var left_keys: [7]u32 = undefined;
    i = 0;
    while (i < half_cells) : (i += 1) {
        left_cells[i] = node.getLeafCell(&left_buf, i);
        left_keys[i] = left_cells[i].key;
    }
    const expected_left_keys: [7]u32 = .{ 0, 1, 2, 3, 4, 5, 6 };

    try std.testing.expectEqualSlices(u32, &expected_left_keys, &left_keys);

    var right_cells: [8]node.LeafCell = undefined;
    var right_keys: [8]u32 = undefined;
    i = 0;
    while (i < other_half_cells) : (i += 1) {
        right_cells[i] = node.getLeafCell(&right_buf, i);
        right_keys[i] = right_cells[i].key;
    }

    const expected_right_keys: [8]u32 = .{ 7, 8, 9, 10, 11, 12, 13, 14 };

    try std.testing.expectEqualSlices(u32, &expected_right_keys, &right_keys);

    const vacated_offset = node.getLeafOffset(half_cells);
    const vacated_memory = left_buf[vacated_offset..];

    //uint can't be negative...so this is the same as a @memset.
    var vacated_sum: u32 = 0;
    for (vacated_memory) |v| {
        vacated_sum += v;
    }

    try std.testing.expectEqual(0, vacated_sum);
}

test "leaf split - insert each after" {
    const page_size = 4096;
    var left_buf: [page_size]u8 = undefined;
    @memset(&left_buf, 0);

    node.setNodeTypeHeader(&left_buf, .LEAF);

    //fill left page
    var i: u32 = 0;
    while (i < node.MAX_LEAF_CELLS) : (i += 1) {
        try leafInsert(&left_buf, .{ .key = i * 2, .value = @splat(1) });
    }

    // ensure page full would be returned
    try std.testing.expectError(
        TreeError.PageFull,
        leafInsert(&left_buf, .{ .key = i + 1, .value = @splat(1) }),
    );

    var right_buf: [page_size]u8 = undefined;
    @memset(&right_buf, 0);

    const new_key = leafSplit(&left_buf, &right_buf);
    _ = new_key;

    try leafInsert(&left_buf, .{ .key = 1, .value = @splat(2) });
    const left_search = try leafSearch(&left_buf, 1);

    try leafInsert(&right_buf, .{ .key = 27, .value = @splat(2) });
    const right_search = try leafSearch(&right_buf, 27);

    try std.testing.expectEqual(true, left_search.found);
    try std.testing.expectEqual(true, right_search.found);

    try std.testing.expectEqual(1, left_search.index);
    try std.testing.expectEqual(7, right_search.index);
}
