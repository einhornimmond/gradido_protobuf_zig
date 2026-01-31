const std = @import("std");
const encode = @import("encode.zig");
const decode = @import("decode.zig");
const grdw = @import("c.zig").grdw;

fn withDualAllocator(
    comptime Func: anytype,
    args: anytype,
) !usize {
    var stack_buffer: [1024]u8 = undefined;
    var fixed_allocator = std.heap.FixedBufferAllocator.init(stack_buffer[0..]);

    return @call(.auto, Func, .{fixed_allocator.allocator()} ++ args) catch |err| {
        switch (err) {
            error.OutOfMemory => {
                const result = try @call(.auto, Func, .{std.heap.c_allocator} ++ args);

                std.log.warn("Function {s} needed dynamic allocator, used {d} bytes", .{ @typeName(@TypeOf(Func)), result });
                return result;
            },
            else => return err,
        }
    };
}

fn wrapCodec(
    comptime Func: anytype,
    args: anytype,
) c_int {
    const result = withDualAllocator(Func, args) catch |err| {
        std.log.err("Codec error in {s}: {}", .{ @typeName(@TypeOf(Func)), err });
        return -1;
    };
    return @intCast(result);
}

export fn grdw_confirmed_transaction_decode(grdw_confirmed_transaction: *grdw.grdw_confirmed_transaction, data: *const u8, size: usize) callconv(.c) c_int {
    return wrapCodec(decode.grdw_confirmed_transaction_decode, .{ grdw_confirmed_transaction, data, size });
}
export fn grdw_transaction_body_decode(grdw_transaction_body: *grdw.grdw_transaction_body, data: *const u8, size: usize) callconv(.c) c_int {
    return wrapCodec(decode.grdw_transaction_body_decode, .{ grdw_transaction_body, data, size });
}
export fn grdw_transaction_body_encode(grdw_transaction_body: *const grdw.grdw_transaction_body, data: *u8, size: usize) callconv(.c) c_int {
    return wrapCodec(encode.grdw_transaction_body_encode, .{ grdw_transaction_body, data, size });
}
