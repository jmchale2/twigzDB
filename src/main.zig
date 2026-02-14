const std = @import("std");
const Io = std.Io;
const pager = @import("pager.zig");

const print = std.debug.print;

fn initDBFile(io: std.Io, file_handle: []const u8) !std.Io.File {
    const cwd = std.Io.Dir.cwd();

    const file = try cwd.createFile(
        io,
        file_handle,
        .{},
    );

    return file;
}

fn getDBFile(io: std.Io, file_handle: []const u8) !std.Io.File {
    const cwd = std.Io.Dir.cwd();

    const file = cwd.openFile(
        io,
        file_handle,
        .{},
    ) catch |e| switch (e) {
        error.FileNotFound => return initDBFile(io, file_handle),
        else => return e,
    };

    return file;
}

pub fn main(init: std.process.Init) !void {
    // In order to do I/O operations need an `Io` instance
    const io = init.io;

    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const file = try getDBFile(io, "data/data.zdb");

    defer file.close(io);

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    try std.Io.File.stdout().writeStreamingAll(io, "Hello, World!\n");

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
