const std = @import("std");
// const gradido_protobuf_zig = @import("gradido_protobuf_zig");
const gradido = @import("proto/gradido.pb.zig");
const Profiler = @import("profiler.zig").Profiler;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const cwd = std.fs.cwd();
    var file = try cwd.openFile("bin.dat", .{});
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    var bytes_read: u64 = 0;
    var tx_count: usize = 0;

    var data_buffer: [800]u8 = undefined;
    var profiler = Profiler.init();

    while (true) {
        const remaining = file_size - bytes_read;

        if (remaining == 32) {
            // var hash: [32]u8 = undefined;
            // try file.readAll(&hash);
            // bytes_read += 32;
            // std.debug.print("Final hash read (32 bytes)\n", .{});
            break;
        }

        if (remaining < 32) {
            return error.InvalidFileLayout;
        }

        // uint16 size lesen (little-endian)
        var size_buf: [2]u8 = undefined;
        _ = try file.readAll(&size_buf);
        bytes_read += 2;
        const b0: u16 = @intCast(size_buf[0]);
        const b1: u16 = @intCast(size_buf[1]);
        const size: u16 = b0 | (b1 << 8);

        // Payload lesen
        // const buffer = try allocator.alloc(u8, size);
        // defer allocator.free(buffer);
        _ = try file.readAll(data_buffer[0..size]);
        var reader: std.io.Reader = .fixed(data_buffer[0..size]);
        var tx = try gradido.ConfirmedTransaction.decode(&reader, allocator);
        defer tx.deinit(allocator);

        bytes_read += size;

        tx_count += 1;
    }
    std.debug.print("Done. Total transactions: {} in {} ms\n", .{ tx_count, profiler.millis() });
}
