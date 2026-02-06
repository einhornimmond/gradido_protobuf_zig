const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const hiero = @import("proto/hiero.pb.zig");
const grdw = @import("c.zig").grdw;

fn reference_c_string(src: [*c]const u8) []const u8 {
    if (src == null) return "";
    const src_size = grdw.grdu_strlen(src);
    if (src_size == 0) {
        return "";
    }
    return src[0..src_size];
}

fn fromCTransferAmount(src: *const grdw.grdw_transfer_amount) gradido.TransferAmount {
    return .{
        .pubkey = &src.pubkey,
        .amount = src.amount,
        .community_id = reference_c_string(src.community_id),
    };
}

fn fromCGradidoTransfer(src: *const grdw.grdw_gradido_transfer) gradido.GradidoTransfer {
    return .{
        .sender = fromCTransferAmount(&src.sender),
        .recipient = &src.recipient,
    };
}

fn fromCTimestamp(timestamp: *const grdw.grdw_timestamp) gradido.Timestamp {
    return .{ .seconds = timestamp.seconds, .nanos = timestamp.nanos };
}

fn fromCLedgerAnchor(src: *const grdw.grdw_ledger_anchor) error{UnknownAnchorIdCase}!gradido.LedgerAnchor {
    switch (src.type) {
        grdw.GRDW_LEDGER_ANCHOR_TYPE_HIERO_TRANSACTION_ID => {
            const accountID: hiero.AccountID = .{
                .shardNum = src.anchor_id.hiero_transaction_id.*.accountID.shardNum,
                .realmNum = src.anchor_id.hiero_transaction_id.*.accountID.realmNum,
                .account = .{ .accountNum = src.anchor_id.hiero_transaction_id.*.accountID.accountNum },
            };
            const transactionValidStart: gradido.Timestamp = .{
                .seconds = src.anchor_id.hiero_transaction_id.*.transactionValidStart.seconds,
                .nanos = src.anchor_id.hiero_transaction_id.*.transactionValidStart.nanos,
            };
            const hiero_transaction_id: hiero.TransactionID = .{
                .transactionValidStart = transactionValidStart,
                .accountID = accountID,
            };
            return .{ .type = .HIERO_TRANSACTION_ID, .anchor_id = .{ .hiero_transaction_id = hiero_transaction_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_UNSPECIFIED => {
            return .{ .type = .UNSPECIFIED, .anchor_id = null };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_TRANSACTION_ID => {
            return .{ .type = .LEGACY_GRADIDO_DB_TRANSACTION_ID, .anchor_id = .{ .legacy_transaction_id = src.anchor_id.legacy_transaction_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_COMMUNITY_ID => {
            return .{ .type = .LEGACY_GRADIDO_DB_COMMUNITY_ID, .anchor_id = .{ .legacy_community_id = src.anchor_id.legacy_community_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_USER_ID => {
            return .{ .type = .LEGACY_GRADIDO_DB_USER_ID, .anchor_id = .{ .legacy_user_id = src.anchor_id.legacy_user_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_CONTRIBUTION_ID => {
            return .{ .type = .LEGACY_GRADIDO_DB_CONTRIBUTION_ID, .anchor_id = .{ .legacy_contribution_id = src.anchor_id.legacy_contribution_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_TRANSACTION_LINK_ID => {
            return .{ .type = .LEGACY_GRADIDO_DB_TRANSACTION_LINK_ID, .anchor_id = .{ .legacy_transaction_link_id = src.anchor_id.legacy_transaction_link_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_NODE_TRIGGER_TRANSACTION_ID => {
            return .{ .type = .NODE_TRIGGER_TRANSACTION_ID, .anchor_id = .{ .node_trigger_transaction_id = src.anchor_id.node_trigger_transaction_id } };
        },
        grdw.GRDW_LEDGER_ANCHOR_TYPE_IOTA_MESSAGE_ID => {
            return .{ .type = .IOTA_MESSAGE_ID, .anchor_id = .{ .iota_message_id = src.anchor_id.iota_message_id[0..32] } };
        },
        else => {
            std.log.err("Unknown anchor id case: {}\n", .{src.type});
            return error.UnknownAnchorIdCase;
        },
    }
}

fn fromCGradidoTransaction(allocator: std.mem.Allocator, tx: *const grdw.grdw_gradido_transaction) !gradido.GradidoTransaction {
    var gradido_tx: gradido.GradidoTransaction = .{
        .sig_map = null,
        .body_Bytes = &[_]u8{},
        .pairing_ledger_anchor = null,
    };
    if (tx.*.body_bytes_size > 0) {
        gradido_tx.body_Bytes = tx.*.body_bytes[0..tx.*.body_bytes_size];
    }
    if (tx.*.sig_map_count > 0) {
        var sigMap: gradido.SignatureMap = .{};
        try sigMap.sig_pair.ensureTotalCapacity(allocator, @intCast(tx.*.sig_map_count));
        for (0..tx.*.sig_map_count) |i| {
            try sigMap.sig_pair.append(allocator, .{
                .pubkey = tx.*.sig_map[i].public_key[0..32],
                .signature = tx.*.sig_map[i].signature[0..64],
            });
        }
        gradido_tx.sig_map = sigMap;
    }

    gradido_tx.pairing_ledger_anchor = try fromCLedgerAnchor(&tx.*.pairing_ledger_anchor);
    return gradido_tx;
}

pub fn grdw_confirmed_transaction_encode(allocator: std.mem.Allocator, tx: *const grdw.grdw_confirmed_transaction, data: [*c]u8, size: usize) error{ OutOfMemory, WriteFailed, UnknownTransactionType, UnknownAnchorIdCase, EndOfStream }!grdw.grdw_encode_result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var confirmedTx: gradido.ConfirmedTransaction = .{};
    confirmedTx.id = tx.*.id;
    confirmedTx.transaction = try fromCGradidoTransaction(allocator, &tx.*.transaction);
    confirmedTx.confirmed_at = fromCTimestamp(&tx.confirmed_at);
    confirmedTx.version_number = reference_c_string(tx.version_number);
    confirmedTx.running_hash = tx.*.running_hash[0..32];
    confirmedTx.ledger_anchor = try fromCLedgerAnchor(&tx.*.ledger_anchor);
    if (tx.*.account_balances_count > 0) {
        try confirmedTx.account_balances.ensureTotalCapacity(allocator, @intCast(tx.*.account_balances_count));
        for (0..tx.*.account_balances_count) |i| {
            var accountBalance: gradido.AccountBalance = .{};
            accountBalance.pubkey = tx.*.account_balances[i].pubkey[0..32];
            accountBalance.balance = tx.*.account_balances[i].balance;
            accountBalance.community_id = reference_c_string(tx.*.account_balances[i].community_id);
            try confirmedTx.account_balances.append(allocator, accountBalance);
        }
    }
    confirmedTx.balance_derivation = @enumFromInt(tx.*.balance_derivation);

    var c_caller_buffer_alloc = std.heap.FixedBufferAllocator.init(data[0..size]);
    var writer = std.io.Writer.Allocating.init(c_caller_buffer_alloc.allocator());
    try writer.ensureUnusedCapacity(512);
    try confirmedTx.encode(&writer.writer, arena.allocator());
    return .{
        .allocator_used = @intCast(arena.state.end_index),
        .written = @intCast(writer.writer.end),
        .state = grdw.GRDW_ENCODING_ERROR_SUCCESS,
    };
}

pub fn grdw_gradido_transaction_encode(allocator: std.mem.Allocator, tx: *const grdw.grdw_gradido_transaction, data: [*c]u8, size: usize) error{ OutOfMemory, WriteFailed, UnknownTransactionType, UnknownAnchorIdCase, EndOfStream }!grdw.grdw_encode_result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var gradido_tx = try fromCGradidoTransaction(allocator, tx);

    var c_caller_buffer_alloc = std.heap.FixedBufferAllocator.init(data[0..size]);
    var writer = std.io.Writer.Allocating.init(c_caller_buffer_alloc.allocator());
    try writer.ensureUnusedCapacity(512);
    try gradido_tx.encode(&writer.writer, arena.allocator());
    return .{
        .allocator_used = @intCast(arena.state.end_index),
        .written = @intCast(writer.writer.end),
        .state = grdw.GRDW_ENCODING_ERROR_SUCCESS,
    };
}

pub fn grdw_transaction_body_encode(allocator: std.mem.Allocator, c_body: *const grdw.grdw_transaction_body, data: [*c]u8, size: usize) error{ OutOfMemory, WriteFailed, UnknownTransactionType, EndOfStream }!grdw.grdw_encode_result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var body: gradido.TransactionBody = .{
        .created_at = fromCTimestamp(&c_body.created_at),
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
    return .{
        .allocator_used = @intCast(arena.state.end_index),
        .written = @intCast(writer.writer.end),
        .state = grdw.GRDW_ENCODING_ERROR_SUCCESS,
    };
}
