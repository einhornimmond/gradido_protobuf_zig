const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const Profiler = @import("profiler.zig").Profiler;

const grdw = @cImport({
    @cInclude("gradido_protobuf_zig.h");
});

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

export fn grdw_confirmed_transaction_decode(tx: *grdw.grdw_confirmed_transaction, data: [*]u8, size: usize) c_int {
    const tx_slice: []u8 = data[0..size];
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var reader: std.io.Reader = .fixed(tx_slice);
    const decoded_tx = gradido.ConfirmedTransaction.decode(&reader, arena.allocator()) catch |err| {
        std.debug.print("Error decoding transaction: {}\n", .{err});
        return -1;
    };
    tx.* = .{
        .id = decoded_tx.id,
        .confirmed_at = .{
            .seconds = decoded_tx.confirmed_at.?.seconds,
            .nanos = decoded_tx.confirmed_at.?.nanos,
        },
        // .version_number = decoded_tx.version_number,
        .balance_derivation = @intCast(@intFromEnum(decoded_tx.balance_derivation)),
        // .confirmed_at = decoded_tx.confirmed_at,
        // .ledger_anchor = decoded_tx.ledger_anchor,
        // .running_hash = decoded_tx.running_hash,
        // .version_number = decoded_tx.version_number,
    };
    grdw.grdw_confirmed_transaction_set_version_number(tx, @ptrCast(decoded_tx.version_number));
    grdw.grdw_confirmed_transaction_set_running_hash(tx, @ptrCast(decoded_tx.running_hash));
    // ledger anchor
    if (decoded_tx.ledger_anchor) |ledger_anchor| {
        convert_ledger_anchor(&tx.ledger_anchor, &ledger_anchor);
    }

    // account balances
    grdw.grdw_confirmed_transaction_reserve_account_balances(tx, @intCast(decoded_tx.account_balances.items.len));
    var index: u8 = 0;
    for (decoded_tx.account_balances.items) |account_balance| {
        @memcpy(&tx.*.account_balances[index].pubkey, account_balance.pubkey);
        tx.*.account_balances[index].balance = account_balance.balance;
        grdw.grdw_account_balance_set_community_id(&tx.*.account_balances[index], @ptrCast(account_balance.community_id));
        index += 1;
    }
    return 0;
}
