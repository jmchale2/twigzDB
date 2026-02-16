/// btree.zig
///
const std = @import("std");
const pager = @import("pager.zig");
const node = @import("node.zig");

const print = std.debug.print;

const TreeError = error{AlreadyExists};

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

    // node.setNodeType(&page, .LEAF);
    //
    // try pgr.writePage(page_number, page);
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

    node.setNodeTypeHeader(&buf, .LEAF);

    const page: [page_size]u8 = @splat(0);

    try std.testing.expectEqual(page, buf);
}

pub fn search(pgr: pager.Pager, page_number: u32, key: u32) !SearchResult {
    var page_buf: [pgr.page_size]u8 = undefined;
    try pgr.readPage(page_number, &page_buf);

    const n_cells = node.getCellCountHeader(&page_buf);

    var low: u32 = 0;
    var high: u32 = n_cells;
    var mid: u32 = undefined;

    while (low < high) {
        mid = @divFloor(low + high, 2);

        const mid_key = node.getLeafCell(&page_buf, mid).key;
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
        results[i] = try search(pgr, @as(u32, @intCast(page_idx)), v);
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
        results[i] = try search(pgr, @as(u32, @intCast(page_idx)), v);
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
        results[i] = try search(pgr, @as(u32, @intCast(page_idx)), v);
    }

    try std.testing.expectEqualSlices(SearchResult, &expected_results, &results);
}
