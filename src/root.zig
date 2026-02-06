const std = @import("std");
const encode = @import("encode.zig");
const decode = @import("decode.zig");
const grdw = @import("c.zig").grdw;

fn withDualAllocator(
    comptime Func: anytype,
    comptime bufferSize: usize,
    args: anytype,
) !usize {
    var stack_buffer: [bufferSize]u8 = undefined;
    var fixed_allocator = std.heap.FixedBufferAllocator.init(stack_buffer[0..]);

    return @call(.auto, Func, .{fixed_allocator.allocator()} ++ args) catch |err| {
        switch (err) {
            error.OutOfMemory, error.WriteFailed => {
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
    comptime bufferSize: usize,
    args: anytype,
) c_int {
    const result = withDualAllocator(Func, bufferSize, args) catch |err| {
        switch (err) {
            error.EndOfStream => {
                return -2;
            },
            else => {
                std.log.err("Codec error in {s}: {}", .{ @typeName(@TypeOf(Func)), err });
                return -1;
            },
        }
    };
    return @intCast(result);
}

export fn grdw_confirmed_transaction_decode(tx: *grdw.grdw_confirmed_transaction, data: *const u8, size: usize) callconv(.c) c_int {
    return wrapCodec(decode.grdw_confirmed_transaction_decode, 1024, .{ tx, data, size });
}
export fn grdw_gradido_transaction_decode(tx: *grdw.grdw_gradido_transaction, data: *const u8, size: usize) c_int {
    return wrapCodec(decode.grdw_gradido_transaction_decode, 1024, .{ tx, data, size });
}
export fn grdw_transaction_body_decode(txBody: *grdw.grdw_transaction_body, data: *const u8, size: usize) callconv(.c) c_int {
    return wrapCodec(decode.grdw_transaction_body_decode, 1024, .{ txBody, data, size });
}

export fn grdw_confirmed_transaction_encode(tx: *const grdw.grdw_confirmed_transaction, data: *u8, size: usize) callconv(.c) c_int {
    return wrapCodec(encode.grdw_confirmed_transaction_encode, 1024, .{ tx, data, size });
}
export fn grdw_gradido_transaction_encode(tx: *const grdw.grdw_gradido_transaction, data: *u8, size: usize) callconv(.c) c_int {
    return wrapCodec(encode.grdw_gradido_transaction_encode, 1024, .{ tx, data, size });
}
export fn grdw_transaction_body_encode(txBody: *const grdw.grdw_transaction_body, data: *u8, size: usize) callconv(.c) c_int {
    return wrapCodec(encode.grdw_transaction_body_encode, 1280, .{ txBody, data, size });
}
