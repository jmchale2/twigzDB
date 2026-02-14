///pager.zig
const std = @import("std");
const print = std.debug.print;

pub const Pager = struct {
    file: std.Io.File,
    comptime page_size: u32 = 4096,

    io: std.Io,

    pub fn init(file: std.Io.File, io: std.Io, comptime page_size: u32) Pager {
        return .{ .file = file, .io = io, .page_size = page_size };
    }

    pub fn pageCount(self: @This()) !u64 {
        const stat = try self.file.stat(self.io);
        const size = stat.size;

        const pages = @divExact(size, self.page_size);
        print("Page Info: {d} bytes is {d} pages.\n", .{ size, pages });
        return pages;
    }

    pub fn readPage(self: @This(), page_number: u64, buff: []u8) !void {
        // std.log.info("Reading page: {s}", self.file_handle);

        const offset = self.page_size * page_number;

        const file = self.file;
        const io = self.io;

        var file_reader = file.reader(io, &.{});
        try file_reader.seekTo(offset);
        const reader = &file_reader.interface;

        const bytes_read = try reader.readSliceShort(buff);

        std.log.info("read : {d}", .{bytes_read});
    }

    pub fn writePage(
        self: @This(),
        page_number: u64,
        data: []u8,
    ) !void {
        const file = self.file;
        const io = self.io;

        const offset = page_number * self.page_size;

        var file_writer = file.writer(io, &.{});
        try file_writer.seekTo(offset);
        const writer = &file_writer.interface;

        const bytes_written = try writer.write(data);

        std.log.info("Wrote {d} bytes\n", .{bytes_written});
    }

    pub fn allocatePage(self: @This()) !u64 {
        const page_count = try self.pageCount();

        const new_page = page_count + 1;
        var buf: [self.page_size]u8 = undefined;
        @memset(&buf, 0);
        try self.writePage(new_page, &buf);

        return new_page;
    }
};

test "pager instantiation" {
    const io = std.testing.io;
    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_pager_instantiation.db", .{});
    defer dir.deleteFile(io, "test_pager_instantiation.db") catch {};

    const page_size = 4096;
    const pager = Pager{ .file = file, .page_size = page_size, .io = io };

    var write_buf: [page_size]u8 = undefined;
    @memset(&write_buf, 1);
    try pager.writePage(0, &write_buf);
    try pager.writePage(1, &write_buf);

    const pages = try pager.pageCount();

    try std.testing.expectEqual(pages, 2);
}

test "pager allocation" {
    const io = std.testing.io;

    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_pager_alloc.db", .{ .read = true });
    defer dir.deleteFile(io, "test_pager_alloc.db") catch {};

    const page_size = 4096;
    var pager = Pager{ .file = file, .page_size = page_size, .io = io };

    var page_count: u64 = 0;
    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        page_count = try pager.allocatePage();
    }

    var ck_buf: [page_size]u8 = undefined;
    @memset(&ck_buf, 0);

    var read_buf: [page_size]u8 = undefined;
    try pager.readPage(page_count, &read_buf);

    try std.testing.expectEqualSlices(u8, &ck_buf, &read_buf);
}

test "pager read/write roundtrip" {
    const io = std.testing.io;

    var tmp_dir = std.testing.tmpDir(.{});
    const dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const file = try dir.createFile(io, "test_pager.db", .{ .read = true });
    defer dir.deleteFile(io, "test_pager.db") catch {};

    const page_size = 4096;
    var pager = Pager{ .file = file, .page_size = page_size, .io = io };

    var write_buf: [page_size]u8 = undefined;
    @memset(&write_buf, 0xAA);
    try pager.writePage(0, &write_buf);

    var read_buf: [page_size]u8 = undefined;
    try pager.readPage(0, &read_buf);

    try std.testing.expectEqualSlices(u8, &write_buf, &read_buf);
}
