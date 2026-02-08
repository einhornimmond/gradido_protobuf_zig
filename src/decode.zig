const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const grdw = @import("c.zig").grdw;

pub const DecodeError = error{
    BodyBytesSizeTypeOverflow,
    CreationTargetDateIsNull,
    DeferredTransferTransferIsNull,
    EndOfStream,
    InvalidBytesLength,
    InvalidInput,
    NotEnoughData,
    OutOfMemory,
    CAllocFailed,
    ReadFailed,
    RedeemDeferredTransferTransferIsNull,
    TransferAmountIsNull,
    UnknownAnchorIdCase,
    WriteFailed,
};

fn convertLedgerAnchor(c_allocator: *grdw.grdu_memory, c_ledger_anchor: *grdw.grdw_ledger_anchor, src_ledger_anchor: *const gradido.LedgerAnchor) error{ CAllocFailed, UnknownAnchorIdCase }!void {
    if (src_ledger_anchor.anchor_id) |anchor_id| {
        switch (anchor_id) {
            .hiero_transaction_id => |hiero_transaction_id| {
                const transactionValidStart: grdw.grdw_timestamp = .{ .seconds = hiero_transaction_id.transactionValidStart.?.seconds, .nanos = hiero_transaction_id.transactionValidStart.?.nanos };
                const accountID: grdw.grdw_hiero_account_id = .{ .shardNum = hiero_transaction_id.accountID.?.shardNum, .realmNum = hiero_transaction_id.accountID.?.realmNum, .accountNum = hiero_transaction_id.accountID.?.account.?.accountNum };
                const hiero_transaction_id_ptr = grdw.grdw_hiero_transaction_id_new(c_allocator, &transactionValidStart, &accountID);
                grdw.grdw_ledger_anchor_set_hiero_transaction_id(c_ledger_anchor, hiero_transaction_id_ptr);
                if (hiero_transaction_id_ptr == null) return error.CAllocFailed;
            },
            .legacy_transaction_id => |legacy_transaction_id| {
                c_ledger_anchor.type = grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_TRANSACTION_ID;
                c_ledger_anchor.anchor_id.legacy_transaction_id = legacy_transaction_id;
            },
            .node_trigger_transaction_id => |node_trigger_transaction_id| {
                c_ledger_anchor.type = grdw.GRDW_LEDGER_ANCHOR_TYPE_NODE_TRIGGER_TRANSACTION_ID;
                c_ledger_anchor.anchor_id.node_trigger_transaction_id = node_trigger_transaction_id;
            },
            .legacy_community_id => |legacy_community_id| {
                c_ledger_anchor.type = grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_COMMUNITY_ID;
                c_ledger_anchor.anchor_id.legacy_community_id = legacy_community_id;
            },
            .legacy_user_id => |legacy_user_id| {
                c_ledger_anchor.type = grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_USER_ID;
                c_ledger_anchor.anchor_id.legacy_user_id = legacy_user_id;
            },
            .legacy_contribution_id => |legacy_contribution_id| {
                c_ledger_anchor.type = grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_CONTRIBUTION_ID;
                c_ledger_anchor.anchor_id.legacy_contribution_id = legacy_contribution_id;
            },
            .legacy_transaction_link_id => |legacy_transaction_link_id| {
                c_ledger_anchor.type = grdw.GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_TRANSACTION_LINK_ID;
                c_ledger_anchor.anchor_id.legacy_transaction_link_id = legacy_transaction_link_id;
            },
            else => {
                std.log.err("Unknown anchor id case: {}\n", .{src_ledger_anchor.type});
                return error.UnknownAnchorIdCase;
            },
        }
    }
}

fn copyString(c_allocator: *grdw.grdu_memory, src: ?[]const u8) error{CAllocFailed}![*c]u8 {
    if (src) |s| {
        if (s.len == 0) {
            return null;
        }
        const result = grdw.grdu_reserve_copy_string(c_allocator, @ptrCast(s), s.len);
        if (result == null) return error.CAllocFailed;
        return result;
    }
    return null;
}

fn copyBytes(c_allocator: *grdw.grdu_memory, src: []const u8) error{CAllocFailed}![*c]u8 {
    if (src.len == 0) {
        return null;
    }
    const result = grdw.grdu_reserve_copy(c_allocator, @ptrCast(src), src.len);
    if (result == null) return error.CAllocFailed;
    return result;
}

fn ConvertTransferAmount(c_allocator: *grdw.grdu_memory, src: ?gradido.TransferAmount) error{ TransferAmountIsNull, CAllocFailed }!grdw.grdw_transfer_amount {
    if (src) |s| {
        var result = grdw.grdw_transfer_amount{
            .amount = @intCast(s.amount),
            .community_id = try copyString(c_allocator, s.community_id),
        };
        if (result.community_id == null and s.community_id.len > 0) return error.CAllocFailed;
        @memcpy(result.pubkey[0..32], s.pubkey);
        return result;
    }
    return error.TransferAmountIsNull;
}

fn ConvertGradidoTransfer(c_allocator: *grdw.grdu_memory, src: gradido.GradidoTransfer) error{ TransferAmountIsNull, CAllocFailed }!grdw.grdw_gradido_transfer {
    var result = grdw.grdw_gradido_transfer{
        .sender = try ConvertTransferAmount(c_allocator, src.sender),
    };
    @memcpy(result.recipient[0..32], src.recipient);
    return result;
}

fn convertGradidoTransaction(c_allocator: *grdw.grdu_memory, gradido_tx: gradido.GradidoTransaction, tx: *grdw.grdw_gradido_transaction) DecodeError!void {
    // signature map
    if (gradido_tx.sig_map) |sig_map| if (sig_map.sig_pair.items.len > 0) {
        grdw.grdw_gradido_transaction_reserve_sig_map(c_allocator, tx, @intCast(sig_map.sig_pair.items.len));
        if (tx.sig_map == null) return error.CAllocFailed;
        for (0..sig_map.sig_pair.items.len) |i| {
            const sig_pair = sig_map.sig_pair.items[i];
            @memcpy(&tx.*.sig_map[i].public_key, sig_pair.pubkey);
            @memcpy(&tx.*.sig_map[i].signature, sig_pair.signature);
        }
    };
    // pairing ledger anchor
    if (gradido_tx.pairing_ledger_anchor) |pairing_ledger_anchor| {
        try convertLedgerAnchor(c_allocator, &tx.*.pairing_ledger_anchor, &pairing_ledger_anchor);
    }
    // body bytes
    if (gradido_tx.body_Bytes.len > 0) {
        grdw.grdw_gradido_transaction_set_body_bytes(c_allocator, tx, @ptrCast(gradido_tx.body_Bytes), @intCast(gradido_tx.body_Bytes.len));
        if (tx.body_bytes == null) return error.CAllocFailed;
        if (@as(usize, @intCast(tx.body_bytes_size)) != gradido_tx.body_Bytes.len) {
            return error.BodyBytesSizeTypeOverflow;
        }
    }
}

fn convertTransactionBody(c_allocator: *grdw.grdu_memory, decoded_tx: gradido.TransactionBody, body: *grdw.grdw_transaction_body) DecodeError!void {
    body.* = .{
        .memos = null,
        .memos_count = 0,
        .created_at = .{
            .seconds = decoded_tx.created_at.?.seconds,
            .nanos = decoded_tx.created_at.?.nanos,
        },
        .transaction_type = grdw.GRDW_TRANSACTION_TYPE_NONE,
        .version_number = try copyString(c_allocator, decoded_tx.version_number),
        .type = @intCast(@intFromEnum(decoded_tx.type)),
        .other_group = try copyString(c_allocator, decoded_tx.other_group),
        .data = undefined,
    };
    if (body.version_number == null or (body.other_group == null and decoded_tx.other_group.len > 0)) {
        return error.CAllocFailed;
    }
    // memos
    if (decoded_tx.memos.items.len > 0) {
        grdw.grdw_transaction_body_reserve_memos(c_allocator, body, @intCast(decoded_tx.memos.items.len));
        if (body.memos == null) return error.CAllocFailed;
        for (0..decoded_tx.memos.items.len) |i| {
            const memo = decoded_tx.memos.items[i];
            body.*.memos[i].type = @intCast(@intFromEnum(memo.type));
            body.*.memos[i].memo = try copyBytes(c_allocator, memo.memo);
            body.*.memos[i].memo_size = @intCast(memo.memo.len);
            if (body.memos[i].memo == null and memo.memo.len > 0) return error.CAllocFailed;
        }
    }
    // specific transaction
    if (decoded_tx.data) |body_data| {
        switch (body_data) {
            .transfer => |transfer| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_TRANSFER;
                body.*.data.transfer = grdw.grdw_gradido_transfer_new(c_allocator, try ConvertTransferAmount(c_allocator, transfer.sender), @ptrCast(transfer.recipient));
                if (body.data.transfer == null) return error.CAllocFailed;
            },
            .creation => |creation| {
                if (creation.target_date) |target_date| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_CREATION;
                    body.*.data.creation = grdw.grdw_gradido_creation_new(
                        c_allocator,
                        try ConvertTransferAmount(c_allocator, creation.recipient),
                        grdw.grdw_timestamp_seconds{ .seconds = @intCast(target_date.seconds) },
                    );
                    if (body.data.creation == null) return error.CAllocFailed;
                } else {
                    return error.CreationTargetDateIsNull;
                }
            },
            .community_friends_update => |community_friends_update| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_FRIENDS_UPDATE;
                body.*.data.community_friends_update = grdw.grdw_community_friends_update_new(c_allocator, community_friends_update.color_fusion);
                if (body.data.community_friends_update == null) return error.CAllocFailed;
            },
            .register_address => |register_address| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_REGISTER_ADDRESS;
                if (register_address.user_pubkey.len != 32) {
                    std.log.err("register_address.user_pubkey.len invalid: {d}, 32 expected\n", .{register_address.user_pubkey.len});
                    return error.InvalidBytesLength;
                }
                if (register_address.name_hash.len != 32) {
                    std.log.err("register_address.name_hash.len invalid: {d}, 32 expected\n", .{register_address.name_hash.len});
                    return error.InvalidBytesLength;
                }
                if (register_address.account_pubkey.len != 32) {
                    std.log.err("register_address.account_pubkey.len invalid: {d}, 32 expected\n", .{register_address.account_pubkey.len});
                    return error.InvalidBytesLength;
                }
                body.*.data.register_address = grdw.grdw_register_address_new(c_allocator, @ptrCast(register_address.user_pubkey), @intCast(@intFromEnum(register_address.address_type)), @ptrCast(register_address.name_hash), @ptrCast(register_address.account_pubkey), @intCast(register_address.derivation_index));
                if (body.data.register_address == null) return error.CAllocFailed;
            },
            .deferred_transfer => |deferred_transfer| {
                if (deferred_transfer.transfer) |transfer| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_DEFERRED_TRANSFER;
                    body.*.data.deferred_transfer = grdw.grdw_gradido_deferred_transfer_new(c_allocator, try ConvertGradidoTransfer(c_allocator, transfer), @intCast(deferred_transfer.timeout_duration.?.seconds));
                    if (body.data.deferred_transfer == null) return error.CAllocFailed;
                } else {
                    return error.DeferredTransferTransferIsNull;
                }
            },
            .community_root => |community_root| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_ROOT;
                body.*.data.community_root = grdw.grdw_community_root_new(c_allocator, @ptrCast(community_root.pubkey), @ptrCast(community_root.gmw_pubkey), @ptrCast(community_root.auf_pubkey));
                if (body.data.community_root == null) return error.CAllocFailed;
            },
            .redeem_deferred_transfer => |redeem_deferred_transfer| {
                if (redeem_deferred_transfer.transfer) |transfer| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_REDEEM_DEFERRED_TRANSFER;
                    body.*.data.redeem_deferred_transfer = grdw.grdw_gradido_redeem_deferred_transfer_new(c_allocator, @intCast(redeem_deferred_transfer.deferredTransferTransactionNr), try ConvertGradidoTransfer(c_allocator, transfer));
                    if (body.data.redeem_deferred_transfer == null) return error.CAllocFailed;
                } else {
                    return error.RedeemDeferredTransferTransferIsNull;
                }
            },
            .timeout_deferred_transfer => |timeout_deferred_transfer| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_TIMEOUT_DEFERRED_TRANSFER;
                body.*.data.timeout_deferred_transfer = grdw.grdw_gradido_timeout_deferred_transfer_new(c_allocator, @intCast(timeout_deferred_transfer.deferredTransferTransactionNr));
                if (body.data.timeout_deferred_transfer == null) return error.CAllocFailed;
            },
        }
    }
}

fn convertConfirmedTransaction(c_allocator: *grdw.grdu_memory, decoded_tx: gradido.ConfirmedTransaction, tx: *grdw.grdw_confirmed_transaction) DecodeError!void {
    tx.* = .{
        .id = decoded_tx.id,
        .confirmed_at = .{
            .seconds = decoded_tx.confirmed_at.?.seconds,
            .nanos = decoded_tx.confirmed_at.?.nanos,
        },
        .version_number = try copyString(c_allocator, decoded_tx.version_number),
        .balance_derivation = @intCast(@intFromEnum(decoded_tx.balance_derivation)),
        // .ledger_anchor = decoded_tx.ledger_anchor,
        .running_hash = try copyBytes(c_allocator, decoded_tx.running_hash),
    };
    if (tx.version_number == null or (tx.running_hash == null and decoded_tx.running_hash.len > 0)) {
        return error.CAllocFailed;
    }

    // GradidoTransaction
    if (decoded_tx.transaction) |transaction| {
        try convertGradidoTransaction(c_allocator, transaction, &tx.transaction);
    }

    // ledger anchor
    if (decoded_tx.ledger_anchor) |ledger_anchor| {
        try convertLedgerAnchor(c_allocator, &tx.ledger_anchor, &ledger_anchor);
    }

    // account balances
    if (decoded_tx.account_balances.items.len > 0) {
        grdw.grdw_confirmed_transaction_reserve_account_balances(c_allocator, tx, @intCast(decoded_tx.account_balances.items.len));
        if (tx.account_balances == null) return error.CAllocFailed;
        for (0..decoded_tx.account_balances.items.len) |i| {
            // for (decoded_tx.account_balances.items) |account_balance| {
            const account_balance = decoded_tx.account_balances.items[i];
            @memcpy(&tx.*.account_balances[i].pubkey, account_balance.pubkey);
            tx.*.account_balances[i].balance = account_balance.balance;
            tx.*.account_balances[i].community_id = try copyString(c_allocator, account_balance.community_id);
            if (tx.account_balances[i].community_id == null and account_balance.community_id.len > 0) return error.CAllocFailed;
        }
    }
}
pub fn Decode(allocator: std.mem.Allocator, c_allocator: *grdw.grdu_memory, comptime T: type, tx: *T, data: [*c]const u8, size: usize) DecodeError!grdw.grdw_encode_result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var reader: std.io.Reader = .fixed(data[0..size]);

    switch (T) {
        grdw.grdw_confirmed_transaction => {
            const decoded_tx = try gradido.ConfirmedTransaction.decode(&reader, arena.allocator());
            try convertConfirmedTransaction(c_allocator, decoded_tx, tx);
        },
        grdw.grdw_gradido_transaction => {
            const decoded_tx = try gradido.GradidoTransaction.decode(&reader, arena.allocator());
            try convertGradidoTransaction(c_allocator, decoded_tx, tx);
        },
        grdw.grdw_transaction_body => {
            const decoded_tx = try gradido.TransactionBody.decode(&reader, arena.allocator());
            try convertTransactionBody(c_allocator, decoded_tx, tx);
        },
        else => return error.InvalidInput,
    }

    return .{
        .allocator_used = @intCast(arena.state.end_index),
        .written = 0,
        .state = grdw.GRDW_ENCODING_ERROR_SUCCESS,
    };
}
