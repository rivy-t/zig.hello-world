// also see: <https://github.com/ziglang/zig/blob/9a18db8a80c96d206297e865d203b2a7d8a803ba/test/cli.zig>

const std = @import("std");
const fmt = std.fmt;
const win32 = std.os.windows;

const Allocator = std.heap.page_allocator;

fn convertUtf16leToUtf8(allocator: std.mem.Allocator, buf: []u16) anyerror![:0]u8 {
    return std.unicode.utf16leToUtf8AllocZ(allocator, buf) catch |err| switch (err) {
        error.ExpectedSecondSurrogateHalf,
        error.DanglingSurrogateHalf,
        error.UnexpectedSecondSurrogateHalf,
        => return error.InvalidCmdLine,
        error.OutOfMemory => return error.OutOfMemory,
    };
}

fn win32CommandLine(allocator: std.mem.Allocator) ![:0]u8 {
    var command_line_raw_U16LE: win32.PWSTR = win32.kernel32.GetCommandLineW();
    // std.log.debug("command_line_raw_U16LE = '{any}'", .{ command_line_raw_U16LE });
    var command_line_buf = std.ArrayList(u16).init(allocator);
    defer command_line_buf.deinit();
    var i: usize = 0;
    var done = false;
    while (!done) {
        // command_line_buf.append(std.mem.littleToNative(command_line_raw_U16LE[i]));
        var val: u16 = std.mem.littleToNative(u16, command_line_raw_U16LE[i]);
        switch (val) {
            0 => done = true,
            else => command_line_buf.append(val) catch unreachable,
        }
        i = i + 1;
        // std.log.debug("val = {}", .{ val });
    }
    return try convertUtf16leToUtf8(allocator, command_line_buf.items);
}

pub fn main() anyerror!void {
    const allocator = Allocator;
    const stdout = std.io.getStdOut().writer();

    // const name = "main.zig";
    // const path = try fmt.allocPrint(allocator, "src/{s}", .{name});
    // defer allocator.free(path);
    // std.log.debug("source path = '{s}'", .{path});

    const command_line = try win32CommandLine(allocator);
    defer allocator.free(command_line);
    std.log.debug("command_line = '{s}'", .{command_line});

    std.log.info("Starting...", .{});

    try stdout.print("All your codebase are belong to us.\n", .{});

    std.log.info("... done.", .{});
}
