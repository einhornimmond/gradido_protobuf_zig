const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const grdw = @import("c.zig").grdw;

fn reference_c_string(src: [*c]const u8) []const u8 {
    if (src == null) return "";
    const src_size = grdw.grdu_strlen(src);
    if (src_size == 0) {
        return "";
    }
    return src[0..src_size];
}

fn fromCTransferAmount(src: *grdw.grdw_transfer_amount) gradido.TransferAmount {
    return .{
        .pubkey = &src.pubkey,
        .amount = src.amount,
        .community_id = reference_c_string(src.community_id),
    };
}

fn fromCGradidoTransfer(src: *grdw.grdw_gradido_transfer) gradido.GradidoTransfer {
    return .{
        .sender = fromCTransferAmount(&src.sender),
        .recipient = &src.recipient,
    };
}

pub fn grdw_transaction_body_encode(allocator: std.mem.Allocator, c_body: *const grdw.grdw_transaction_body, data: [*c]u8, size: usize) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var body: gradido.TransactionBody = .{
        .created_at = .{
            .seconds = c_body.created_at.seconds,
            .nanos = c_body.created_at.nanos,
        },
        .version_number = reference_c_string(c_body.version_number),
        .type = @enumFromInt(c_body.type),
        .other_group = reference_c_string(c_body.other_group),
    };
    // memos
    if (c_body.memos_count > 0) {
        try body.memos.ensureTotalCapacity(arena.allocator(), c_body.memos_count);
        for (c_body.memos[0..c_body.memos_count]) |memo| {
            try body.memos.append(arena.allocator(), .{
                .type = @enumFromInt(memo.type),
                .memo = memo.memo[0..memo.memo_size],
            });
        }
    }
    // specific transactions
    switch (c_body.transaction_type) {
        grdw.GRDW_TRANSACTION_TYPE_TRANSFER => {
            body.data = gradido.TransactionBody.data_union{
                .transfer = fromCGradidoTransfer(c_body.data.transfer),
            };
        },
        grdw.GRDW_TRANSACTION_TYPE_CREATION => {
            body.data = gradido.TransactionBody.data_union{
                .creation = .{
                    .recipient = fromCTransferAmount(&c_body.data.creation.*.recipient),
                    .target_date = .{
                        .seconds = c_body.data.creation.*.target_date.seconds,
                    },
                },
            };
        },
        grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_FRIENDS_UPDATE => {
            body.data = gradido.TransactionBody.data_union{
                .community_friends_update = .{
                    .color_fusion = c_body.data.community_friends_update.*.color_fusion,
                },
            };
        },
        grdw.GRDW_TRANSACTION_TYPE_REGISTER_ADDRESS => {
            body.data = gradido.TransactionBody.data_union{
                .register_address = .{
                    .user_pubkey = &c_body.data.register_address.*.user_pubkey,
                    .address_type = @enumFromInt(c_body.data.register_address.*.address_type),
                    .derivation_index = c_body.data.register_address.*.derivation_index,
                    .name_hash = &c_body.data.register_address.*.name_hash,
                    .account_pubkey = &c_body.data.register_address.*.account_pubkey,
                },
            };
        },
        grdw.GRDW_TRANSACTION_TYPE_DEFERRED_TRANSFER => {
            body.data = gradido.TransactionBody.data_union{
                .deferred_transfer = .{
                    .transfer = fromCGradidoTransfer(&c_body.data.deferred_transfer.*.transfer),
                    .timeout_duration = .{
                        .seconds = c_body.data.deferred_transfer.*.timeout_duration,
                    },
                },
            };
        },
        grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_ROOT => {
            body.data = gradido.TransactionBody.data_union{
                .community_root = .{
                    .pubkey = &c_body.data.community_root.*.pubkey,
                    .gmw_pubkey = &c_body.data.community_root.*.gmw_pubkey,
                    .auf_pubkey = &c_body.data.community_root.*.auf_pubkey,
                },
            };
        },
        grdw.GRDW_TRANSACTION_TYPE_REDEEM_DEFERRED_TRANSFER => {
            body.data = gradido.TransactionBody.data_union{ .redeem_deferred_transfer = .{
                .deferredTransferTransactionNr = c_body.data.redeem_deferred_transfer.*.deferred_transfer_transaction_nr,
                .transfer = fromCGradidoTransfer(&c_body.data.redeem_deferred_transfer.*.transfer),
            } };
        },
        grdw.GRDW_TRANSACTION_TYPE_TIMEOUT_DEFERRED_TRANSFER => {
            body.data = gradido.TransactionBody.data_union{ .timeout_deferred_transfer = .{
                .deferredTransferTransactionNr = c_body.data.timeout_deferred_transfer.*.deferred_transfer_transaction_nr,
            } };
        },
        else => {
            std.log.debug("Error decoding transaction: {}\n", .{c_body.transaction_type});
            return error.UnknownTransactionType;
        },
    }

    var c_caller_buffer_alloc = std.heap.FixedBufferAllocator.init(data[0..size]);
    var writer = std.io.Writer.Allocating.init(c_caller_buffer_alloc.allocator());
    try writer.ensureUnusedCapacity(512);
    try body.encode(&writer.writer, arena.allocator());
    return @intCast(writer.writer.buffer.len);
}
