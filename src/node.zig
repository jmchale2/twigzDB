/// node.zig
const std = @import("std");
// const print = std.debug.print;

const NODE_TYPE_OFFSET = 0;
const NODE_TYPE_SIZE = 1;
const N_CELLS_OFFSET = 1;
const N_CELLS_SIZE = 2;
const PARENT_PAGE_OFFSET = 3;
const PARENT_PAGE_SIZE = 4;
const RIGHT_CHILD_OFFSET = 7;
const RIGHT_CHILD_SIZE = 4;
const HEADER_SIZE = 11;

const LEAF_KEY_TYPE: type = u32;
const LEAF_KEY_SIZE = @sizeOf(LEAF_KEY_TYPE);

const LEAF_VALUE_SIZE = 256;
const LEAF_VALUE_TYPE: type = [LEAF_VALUE_SIZE]u8;
const LEAF_CELL_SIZE = LEAF_KEY_SIZE + LEAF_VALUE_SIZE;

const INTERNAL_KEY_TYPE: type = u32;
const INTERNAL_CHILD_TYPE: type = u32;
const INTERNAL_KEY_SIZE = @sizeOf(INTERNAL_KEY_TYPE);
const INTERNAL_CHILD_SIZE = @sizeOf(INTERNAL_CHILD_TYPE);
const INTERNAL_CELL_SIZE = INTERNAL_KEY_SIZE + INTERNAL_CHILD_SIZE;

const NodeType = enum { LEAF, INTERNAL };

const PageHeader = struct {
    rightmost_pointer: ?u32 = null,
    parent_page_no: ?u32 = null,
    n_cells: u16,
    node_type: NodeType,
};

const LeafCell = struct {
    key: LEAF_KEY_TYPE,
    value: LEAF_VALUE_TYPE,
};

const InternalCell = struct {
    key: INTERNAL_KEY_TYPE,
    child_page: INTERNAL_CHILD_TYPE,
};

pub fn setNodeType(page_buf: *[4096]u8, node_type: NodeType) void {
    const node_type_byte = std.mem.toBytes(node_type);
    page_buf[NODE_TYPE_OFFSET] = node_type_byte[0];
}
pub fn getNodeType(page_buf: *[4096]u8) NodeType {
    const node_type = std.mem.bytesToValue(NodeType, page_buf[NODE_TYPE_OFFSET..NODE_TYPE_SIZE]);
    // print("{any}, {any}\n\n", .{ node_type, (@TypeOf(node_type)) });
    return node_type;
}
pub fn getLeafCell(page_buf: []const u8, index: u32) LeafCell {
    const offset = HEADER_SIZE + (index * LEAF_CELL_SIZE);

    const key = std.mem.bytesToValue(LEAF_KEY_TYPE, page_buf[offset..][0..4]);
    const cell = page_buf[offset + LEAF_KEY_SIZE ..][0..LEAF_VALUE_SIZE];
    return .{ .key = key, .value = cell.* };
}

pub fn setLeafCell(page_buf: []u8, index: u32, leaf_cell: LeafCell) void {
    const offset = HEADER_SIZE + (index * LEAF_CELL_SIZE);

    const key_bytes = std.mem.toBytes(leaf_cell.key);
    @memcpy(page_buf[offset..][0..LEAF_KEY_SIZE], &key_bytes);

    @memcpy(page_buf[offset + LEAF_KEY_SIZE ..][0..LEAF_VALUE_SIZE], &leaf_cell.value);
}

test "get/set leaf cell" {
    var page_buf: [4096]u8 = undefined;
    @memset(&page_buf, 0);

    var cell_buf: [256]u8 = undefined;
    @memset(&cell_buf, 1);

    const leaf = LeafCell{ .key = 10, .value = cell_buf };

    std.log.info("leaf in:  {any}\n", .{leaf});

    setLeafCell(&page_buf, 0, leaf);

    const leaf_out = getLeafCell(&page_buf, 0);

    std.log.info("leaf out: {any}\n", .{leaf_out});

    try std.testing.expectEqual(leaf, leaf_out);
}

test "get/set multiple leaf cells" {
    var page_buf: [4096]u8 = undefined;
    @memset(&page_buf, 0);

    var cell_buf: [256]u8 = undefined;
    @memset(&cell_buf, 1);

    var other_cell_buf: [256]u8 = undefined;
    @memset(&other_cell_buf, 2);

    const leaf = LeafCell{ .key = 10, .value = cell_buf };
    const other_leaf = LeafCell{ .key = 25, .value = other_cell_buf };

    // print("leaf in:  {any}\n", .{leaf});
    // print("oleaf in:  {any}\n", .{other_leaf});

    setLeafCell(&page_buf, 0, leaf);
    setLeafCell(&page_buf, 1, other_leaf);

    const leaf_out = getLeafCell(&page_buf, 0);
    const other_leaf_out = getLeafCell(&page_buf, 1);

    // print("leaf out: {any}\n", .{leaf_out});
    // print("oleaf out: {any}\n", .{other_leaf_out});

    try std.testing.expectEqual(leaf, leaf_out);
    try std.testing.expectEqual(other_leaf, other_leaf_out);
}

pub fn getInternalCell(page_buf: []const u8, index: u32) InternalCell {
    const offset = HEADER_SIZE + (index * INTERNAL_CELL_SIZE);

    const key = std.mem.bytesToValue(INTERNAL_KEY_TYPE, page_buf[offset..][0..INTERNAL_KEY_SIZE]);
    const cell = std.mem.bytesToValue(INTERNAL_CHILD_TYPE, page_buf[offset + INTERNAL_KEY_SIZE ..][0..INTERNAL_CHILD_SIZE]);
    return .{ .key = key, .child_page = cell };
}

pub fn setInternalCell(page_buf: []u8, index: u32, internal_cell: InternalCell) void {
    const offset = HEADER_SIZE + (index * INTERNAL_CELL_SIZE);

    const key_bytes = std.mem.toBytes(internal_cell.key);
    @memcpy(page_buf[offset..][0..INTERNAL_KEY_SIZE], &key_bytes);

    const cell_bytes = std.mem.toBytes(internal_cell.child_page);
    @memcpy(page_buf[offset + INTERNAL_KEY_SIZE ..][0..INTERNAL_CHILD_SIZE], &cell_bytes);
}

test "get/set internal cell" {
    var page_buf: [4096]u8 = undefined;
    @memset(&page_buf, 0);

    const cell_buf: INTERNAL_CHILD_TYPE = 1;
    const internal = InternalCell{ .key = 10, .child_page = cell_buf };

    std.log.info("internal in:  {any}\n", .{internal});

    setInternalCell(&page_buf, 0, internal);

    const internal_out = getInternalCell(&page_buf, 0);

    std.log.info("internal out: {any}\n", .{internal_out});

    try std.testing.expectEqual(internal, internal_out);
}

test "get/set multiple internal cell" {
    var page_buf: [4096]u8 = undefined;
    @memset(&page_buf, 0);

    const cell_buf: INTERNAL_CHILD_TYPE = 1;
    const other_cell_buf: INTERNAL_CHILD_TYPE = 2;

    const internal = InternalCell{ .key = 10, .child_page = cell_buf };
    const other_internal = InternalCell{ .key = 25, .child_page = other_cell_buf };

    std.log.info("internal in:  {any}\n", .{internal});
    std.log.info("ointernal in:  {any}\n", .{other_internal});

    setInternalCell(&page_buf, 0, internal);
    setInternalCell(&page_buf, 1, other_internal);

    const internal_out = getInternalCell(&page_buf, 0);
    const other_internal_out = getInternalCell(&page_buf, 1);

    std.log.info("internal out: {any}\n", .{internal_out});
    std.log.info("ointernal out: {any}\n", .{other_internal_out});

    try std.testing.expectEqual(internal, internal_out);
    try std.testing.expectEqual(other_internal, other_internal_out);
}
// struct page_header {
// node_type
// n_cells,
// parent_page_no
// rightmost_pointer }
//
// fn getNodeType(page)
// fn setNodeType(page, node_type)...
// fn getCellCount(page)...
// fn getCell(page, idx )...
// fn setCell(page, idx, cell)...
//
test "page header size" {
    // const header = PageHeader{ .parent_page_no = null, .rightmost_pointer = null, .n_cells = 4, .node_type = .LEAF };
    const ph_size = @sizeOf(PageHeader);
    std.log.info("{d}\n", .{ph_size});

    const bit_ph_size = @bitSizeOf(PageHeader);
    std.log.info("{d}\n", .{bit_ph_size});
}

test "set and get node type" {
    var buf: [4096]u8 = undefined;
    @memset(&buf, 0);

    std.log.info("Initial Headers:  {any:>}\n", .{&buf[0..HEADER_SIZE].*});

    setNodeType(&buf, .LEAF);

    std.log.info("LEAF Headers:     {any:>}\n", .{&buf[0..HEADER_SIZE].*});
    try std.testing.expectEqual(NodeType.LEAF, getNodeType(&buf));

    setNodeType(&buf, .INTERNAL);
    std.log.info("INTERNAL Headers: {any:>}\n", .{&buf[0..HEADER_SIZE].*});

    try std.testing.expectEqual(NodeType.INTERNAL, getNodeType(&buf));
}
