const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const grdw = @import("c.zig").grdw;

fn convert_ledger_anchor(c_ledger_anchor: *grdw.grdw_ledger_anchor, src_ledger_anchor: *const gradido.LedgerAnchor) void {
    if (src_ledger_anchor.anchor_id) |anchor_id| {
        switch (anchor_id) {
            .hiero_transaction_id => |hiero_transaction_id| {
                const transactionValidStart: grdw.grdw_timestamp = .{ .seconds = hiero_transaction_id.transactionValidStart.?.seconds, .nanos = hiero_transaction_id.transactionValidStart.?.nanos };
                const accountID: grdw.grdw_hiero_account_id = .{ .shardNum = hiero_transaction_id.accountID.?.shardNum, .realmNum = hiero_transaction_id.accountID.?.realmNum, .accountNum = hiero_transaction_id.accountID.?.account.?.accountNum };
                const hiero_transaction_id_ptr = grdw.grdw_hiero_transaction_id_new(&transactionValidStart, &accountID);
                grdw.grdw_ledger_anchor_set_hiero_transaction_id(c_ledger_anchor, hiero_transaction_id_ptr);
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
                std.debug.print("Unknown anchor id case: {}\n", .{src_ledger_anchor.type});
            },
        }
    }
}

fn copy_string(src: ?[]const u8) [*c]u8 {
    if (src) |s| {
        if (s.len == 0) {
            return null;
        }
        return grdw.grdu_reserve_copy_string(@ptrCast(s), s.len);
    }
    return null;
}

fn copy_bytes(src: []const u8) [*c]u8 {
    return grdw.grdu_reserve_copy(@ptrCast(src), src.len);
}

fn convertTransferAmount(src: ?gradido.TransferAmount) !grdw.grdw_transfer_amount {
    if (src) |s| {
        var result = grdw.grdw_transfer_amount{
            .amount = @intCast(s.amount),
            .community_id = copy_string(s.community_id),
        };
        @memcpy(result.pubkey[0..32], s.pubkey);
        return result;
    }
    return error.TransferAmountIsNull;
}

fn convertGradidoTransfer(src: gradido.GradidoTransfer) !grdw.grdw_gradido_transfer {
    var result = grdw.grdw_gradido_transfer{
        .sender = try convertTransferAmount(src.sender),
    };
    @memcpy(result.recipient[0..32], src.recipient);
    return result;
}

pub fn grdw_confirmed_transaction_decode(allocator: std.mem.Allocator, tx: *grdw.grdw_confirmed_transaction, data: [*c]const u8, size: usize) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var reader: std.io.Reader = .fixed(data[0..size]);
    const decoded_tx = try gradido.ConfirmedTransaction.decode(&reader, arena.allocator());
    tx.* = .{
        .id = decoded_tx.id,
        .confirmed_at = .{
            .seconds = decoded_tx.confirmed_at.?.seconds,
            .nanos = decoded_tx.confirmed_at.?.nanos,
        },
        .version_number = copy_string(decoded_tx.version_number),
        .balance_derivation = @intCast(@intFromEnum(decoded_tx.balance_derivation)),
        // .ledger_anchor = decoded_tx.ledger_anchor,
        .running_hash = copy_bytes(decoded_tx.running_hash),
    };

    var index: u8 = 0;
    // GradidoTransaction
    if (decoded_tx.transaction) |transaction| {
        // signature map
        index = 0;
        if (transaction.sig_map) |sig_map| {
            grdw.grdw_gradido_transaction_reserve_sig_map(&tx.transaction, @intCast(sig_map.sig_pair.items.len));
            for (sig_map.sig_pair.items) |sig_pair| {
                @memcpy(&tx.*.transaction.sig_map[index].public_key, sig_pair.pubkey);
                @memcpy(&tx.*.transaction.sig_map[index].signature, sig_pair.signature);
                index += 1;
            }
        }
        // pairing ledger anchor
        if (transaction.pairing_ledger_anchor) |pairing_ledger_anchor| {
            convert_ledger_anchor(&tx.*.transaction.pairing_ledger_anchor, &pairing_ledger_anchor);
        }
        // body bytes
        grdw.grdw_gradido_transaction_set_body_bytes(&tx.transaction, @ptrCast(transaction.body_Bytes), @intCast(transaction.body_Bytes.len));
        if (@as(usize, @intCast(tx.transaction.body_bytes_size)) != transaction.body_Bytes.len) {
            return error.BodyBytesSizeTypeOverflow;
        }
    }

    // ledger anchor
    if (decoded_tx.ledger_anchor) |ledger_anchor| {
        convert_ledger_anchor(&tx.ledger_anchor, &ledger_anchor);
    }

    // account balances
    grdw.grdw_confirmed_transaction_reserve_account_balances(tx, @intCast(decoded_tx.account_balances.items.len));
    index = 0;
    for (decoded_tx.account_balances.items) |account_balance| {
        @memcpy(&tx.*.account_balances[index].pubkey, account_balance.pubkey);
        tx.*.account_balances[index].balance = account_balance.balance;
        tx.*.account_balances[index].community_id = copy_string(account_balance.community_id);
        index += 1;
    }
    return arena.queryCapacity();
}

pub fn grdw_transaction_body_decode(allocator: std.mem.Allocator, body: *grdw.grdw_transaction_body, data: [*c]const u8, size: usize) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var reader: std.io.Reader = .fixed(data[0..size]);
    const decoded_tx = try gradido.TransactionBody.decode(&reader, arena.allocator());
    body.* = .{
        .memos = null,
        .memos_count = 0,
        .created_at = .{
            .seconds = decoded_tx.created_at.?.seconds,
            .nanos = decoded_tx.created_at.?.nanos,
        },
        .transaction_type = grdw.GRDW_TRANSACTION_TYPE_NONE,
        .version_number = copy_string(decoded_tx.version_number),
        .type = @intCast(@intFromEnum(decoded_tx.type)),
        .other_group = copy_string(decoded_tx.other_group),
        .data = undefined,
    };
    var index: usize = 0;
    // memos
    if (decoded_tx.memos.items.len > 0) {
        grdw.grdw_transaction_body_reserve_memos(body, @intCast(decoded_tx.memos.items.len));
        for (decoded_tx.memos.items) |memo| {
            body.*.memos[index].type = @intCast(@intFromEnum(memo.type));
            body.*.memos[index].memo = copy_bytes(memo.memo);
            body.*.memos[index].memo_size = @intCast(memo.memo.len);
            index += 1;
        }
    }
    // specific transaction
    if (decoded_tx.data) |body_data| {
        switch (body_data) {
            .transfer => |transfer| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_TRANSFER;
                body.*.data.transfer = grdw.grdw_gradido_transfer_new(try convertTransferAmount(transfer.sender), @ptrCast(transfer.recipient));
            },
            .creation => |creation| {
                if (creation.target_date) |target_date| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_CREATION;
                    body.*.data.creation = grdw.grdw_gradido_creation_new(
                        try convertTransferAmount(creation.recipient),
                        grdw.grdw_timestamp_seconds{ .seconds = @intCast(target_date.seconds) },
                    );
                } else {
                    return error.CreationTargetDateIsNull;
                }
            },
            .community_friends_update => |community_friends_update| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_FRIENDS_UPDATE;
                body.*.data.community_friends_update = grdw.grdw_community_friends_update_new(community_friends_update.color_fusion);
            },
            .register_address => |register_address| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_REGISTER_ADDRESS;
                body.*.data.register_address = grdw.grdw_register_address_new(@ptrCast(register_address.user_pubkey), @intCast(@intFromEnum(register_address.address_type)), @ptrCast(register_address.name_hash), @ptrCast(register_address.account_pubkey), @intCast(register_address.derivation_index));
            },
            .deferred_transfer => |deferred_transfer| {
                if (deferred_transfer.transfer) |transfer| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_DEFERRED_TRANSFER;
                    body.*.data.deferred_transfer = grdw.grdw_gradido_deferred_transfer_new(try convertGradidoTransfer(transfer), @intCast(deferred_transfer.timeout_duration.?.seconds));
                } else {
                    return error.DeferredTransferTransferIsNull;
                }
            },
            .community_root => |community_root| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_ROOT;
                body.*.data.community_root = grdw.grdw_community_root_new(@ptrCast(community_root.pubkey), @ptrCast(community_root.gmw_pubkey), @ptrCast(community_root.auf_pubkey));
            },
            .redeem_deferred_transfer => |redeem_deferred_transfer| {
                if (redeem_deferred_transfer.transfer) |transfer| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_REDEEM_DEFERRED_TRANSFER;
                    body.*.data.redeem_deferred_transfer = grdw.grdw_gradido_redeem_deferred_transfer_new(@intCast(redeem_deferred_transfer.deferredTransferTransactionNr), try convertGradidoTransfer(transfer));
                } else {
                    return error.RedeemDeferredTransferTransferIsNull;
                }
            },
            .timeout_deferred_transfer => |timeout_deferred_transfer| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_TIMEOUT_DEFERRED_TRANSFER;
                body.*.data.timeout_deferred_transfer = grdw.grdw_gradido_timeout_deferred_transfer_new(@intCast(timeout_deferred_transfer.deferredTransferTransactionNr));
            },
        }
    }

    return @intCast(arena.queryCapacity());
}
