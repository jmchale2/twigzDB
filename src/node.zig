/// node.zig
const std = @import("std");
const print = std.debug.print;

// enum node_type (leaf, internal)

const NODE_TYPE_OFFSET = 0;
const NODE_TYPE_SIZE = 1;
const N_CELLS_OFFSET = 1;
const N_CELLS_SIZE = 2;
const PARENT_PAGE_OFFSET = 3;
const PARENT_PAGE_SIZE = 4;
const RIGHT_CHILD_OFFSET = 7;
const RIGHT_CHILD_SIZE = 4;
const HEADER_SIZE = 11;

const NodeType = enum { LEAF, INTERNAL };

const PageHeader = struct {
    //largest to smallest

    rightmost_pointer: ?u32 = null,
    parent_page_no: ?u32 = null,
    n_cells: u16,
    node_type: NodeType,
};

const LeafCell = struct {
    key: u32,
    value: [256]u8,
};

const InternalCell = struct { key: u32, child_page: u32 };

pub fn setNodeType(page_buf: *[4096]u8, node_type: NodeType) void {
    const node_type_byte = std.mem.toBytes(node_type);
    page_buf[NODE_TYPE_OFFSET] = node_type_byte[0];
}
pub fn getNodeType(page_buf: *[4096]u8) NodeType {
    const node_type = std.mem.bytesToValue(NodeType, page_buf[NODE_TYPE_OFFSET..NODE_TYPE_SIZE]);
    // print("{any}, {any}\n\n", .{ node_type, (@TypeOf(node_type)) });
    return node_type;
}
pub fn getCell(page_buf: [4096]u8, idx: u32) []u8 {
    return page_buf[idx .. idx + 256];
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
    print("{d}\n", .{ph_size});

    const bit_ph_size = @bitSizeOf(PageHeader);
    print("{d}\n", .{bit_ph_size});
}

test "set and get node type" {
    var buf: [4096]u8 = undefined;
    @memset(&buf, 0);

    print("Initial Headers:  {any:>}\n", .{&buf[0..HEADER_SIZE].*});

    setNodeType(&buf, .LEAF);

    print("LEAF Headers:     {any:>}\n", .{&buf[0..HEADER_SIZE].*});
    try std.testing.expectEqual(NodeType.LEAF, getNodeType(&buf));

    setNodeType(&buf, .INTERNAL);
    print("INTERNAL Headers: {any:>}\n", .{&buf[0..HEADER_SIZE].*});

    try std.testing.expectEqual(NodeType.INTERNAL, getNodeType(&buf));
}
