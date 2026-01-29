const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const Profiler = @import("profiler.zig").Profiler;

const grdw = @cImport({
    @cInclude("include/gradido_protobuf_zig.h");
});

pub fn main() !void {
    var profiler = Profiler.init();
    const allocator = std.heap.page_allocator;

    const cwd = std.fs.cwd();
    var file = try cwd.openFile("bin.dat", .{});
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    if (file_size < 32) return error.InvalidFileLayout;

    const data_size = file_size - 32; // Letzte 32 bytes = Hash
    var file_buffer = try allocator.alloc(u8, data_size);
    defer allocator.free(file_buffer);

    _ = try file.readAll(file_buffer);
    std.debug.print("Reading File into memory in {} ms\n", .{profiler.millis()});
    profiler.reset();

    var bytes_read: usize = 0;
    var tx_count: usize = 0;

    while (bytes_read < data_size) {
        if (data_size - bytes_read < 2) return error.InvalidFileLayout;

        const size: u16 = @as(u16, @intCast(file_buffer[bytes_read])) |
            (@as(u16, @intCast(file_buffer[bytes_read + 1])) << 8);
        bytes_read += 2;

        if (data_size - bytes_read < size) return error.InvalidFileLayout;

        const slice = file_buffer[bytes_read .. bytes_read + size];
        bytes_read += size;

        // Slice-Reader für decode
        var reader: std.io.Reader = .fixed(slice);

        // Arena-Allocator für Submessages
        var arena = std.heap.ArenaAllocator.init(allocator);
        // defer arena.deinit();
        const aallocator = arena.allocator();
        _ = try gradido.ConfirmedTransaction.decode(&reader, aallocator);
        // defer tx.deinit(aallocator);
        arena.deinit(); // alle Submessages freigeben

        tx_count += 1;
    }

    const hash_slice = file_buffer[data_size..]; // letzte 32 bytes
    std.debug.print("Done. Total transactions: {} in {} ms\n", .{ tx_count, profiler.millis() });
    std.debug.print("Final hash slice len: {}\n", .{hash_slice.len});
}
