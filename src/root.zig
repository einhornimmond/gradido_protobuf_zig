const std = @import("std");
const encode = @import("encode.zig");
const decode = @import("decode.zig");
const grdw = @import("c.zig").grdw;

fn withDualAllocator(
    comptime Func: anytype,
    comptime bufferSize: usize,
    args: anytype,
) !grdw.grdw_encode_result {
    var stack_buffer: [bufferSize]u8 = undefined;
    var fixed_allocator = std.heap.FixedBufferAllocator.init(stack_buffer[0..]);

    return @call(.auto, Func, .{fixed_allocator.allocator()} ++ args) catch |err| {
        switch (err) {
            error.OutOfMemory, error.WriteFailed => {
                const result = try @call(.auto, Func, .{std.heap.c_allocator} ++ args);

                std.log.warn("Function {s} needed dynamic allocator, used {d} bytes", .{ @typeName(@TypeOf(Func)), result.allocator_used });
                return result;
            },
            else => return err,
        }
    };
}

fn errorToGrdwEncodingError(err: anyerror) grdw.grdw_encoding_error {
    switch (err) {
        error.EndOfStream => return grdw.GRDW_ENCODING_ERROR_END_OF_STREAM,
        error.UnknownTransactionType => return grdw.GRDW_ENCODING_ERROR_UNKNOWN_TRANSACTION_TYPE,
        error.BodyBytesSizeTypeOverflow => return grdw.GRDW_ENCODING_ERROR_BODY_BYTES_SIZE_TYPE_OVERFLOW,
        error.CreationTargetDateIsNull => return grdw.GRDW_ENCODING_ERROR_CREATION_TARGET_DATE_IS_NULL,
        error.DeferredTransferTransferIsNull => return grdw.GRDW_ENCODING_ERROR_DEFERRED_TRANSFER_TRANSFER_IS_NULL,
        error.InvalidBytesLength => return grdw.GRDW_ENCODING_ERROR_INVALID_BYTES_LENGTH,
        error.InvalidInput => return grdw.GRDW_ENCODING_ERROR_INVALID_INPUT,
        error.NotEnoughData => return grdw.GRDW_ENCODING_ERROR_NOT_ENOUGH_DATA,
        error.OutOfMemory => return grdw.GRDW_ENCODING_ERROR_OUT_OF_MEMORY,
        error.ReadFailed => return grdw.GRDW_ENCODING_ERROR_READ_FAILED,
        error.RedeemDeferredTransferTransferIsNull => return grdw.GRDW_ENCODING_ERROR_REDEEM_DEFERRED_TRANSFER_TRANSFER_IS_NULL,
        error.TransferAmountIsNull => return grdw.GRDW_ENCODING_ERROR_TRANSFER_AMOUNT_IS_NULL,
        error.UnknownAnchorIdCase => return grdw.GRDW_ENCODING_ERROR_UNKNOWN_ANCHOR_ID_CASE,
        error.WriteFailed => return grdw.GRDW_ENCODING_ERROR_WRITE_FAILED,
        else => return grdw.GRDW_ENCODING_ERROR_UNKNOWN,
    }
}

fn wrapCodec(
    comptime Func: anytype,
    comptime bufferSize: usize,
    args: anytype,
) grdw.grdw_encode_result {
    return withDualAllocator(Func, bufferSize, args) catch |err| {
        return .{
            .allocator_used = 0,
            .written = 0,
            .state = errorToGrdwEncodingError(err),
        };
    };
}

export fn grdw_confirmed_transaction_decode(allocator: *grdw.grdu_memory, tx: *grdw.grdw_confirmed_transaction, data: *const u8, size: usize) callconv(.c) grdw.grdw_encode_result {
    return wrapCodec(decode.Decode, 1024, .{ allocator, grdw.grdw_confirmed_transaction, tx, data, size });
}
export fn grdw_gradido_transaction_decode(allocator: *grdw.grdu_memory, tx: *grdw.grdw_gradido_transaction, data: *const u8, size: usize) grdw.grdw_encode_result {
    return wrapCodec(decode.Decode, 512, .{ allocator, grdw.grdw_gradido_transaction, tx, data, size });
}
export fn grdw_transaction_body_decode(allocator: *grdw.grdu_memory, txBody: *grdw.grdw_transaction_body, data: *const u8, size: usize) callconv(.c) grdw.grdw_encode_result {
    return wrapCodec(decode.Decode, 1024, .{ allocator, grdw.grdw_transaction_body, txBody, data, size });
}

export fn grdw_confirmed_transaction_encode(tx: *const grdw.grdw_confirmed_transaction, data: *u8, size: usize) callconv(.c) grdw.grdw_encode_result {
    return wrapCodec(encode.grdw_confirmed_transaction_encode, 2048, .{ tx, data, size });
}
export fn grdw_gradido_transaction_encode(tx: *const grdw.grdw_gradido_transaction, data: *u8, size: usize) callconv(.c) grdw.grdw_encode_result {
    return wrapCodec(encode.grdw_gradido_transaction_encode, 2048, .{ tx, data, size });
}
export fn grdw_transaction_body_encode(txBody: *const grdw.grdw_transaction_body, data: *u8, size: usize) callconv(.c) grdw.grdw_encode_result {
    return wrapCodec(encode.grdw_transaction_body_encode, 2048, .{ txBody, data, size });
}
