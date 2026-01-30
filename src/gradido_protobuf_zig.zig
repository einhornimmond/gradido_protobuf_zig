const std = @import("std");
const gradido = @import("proto/gradido.pb.zig");
const Profiler = @import("profiler.zig").Profiler;

threadlocal var main_allocator = std.heap.c_allocator;
threadlocal var main_buffer: ?[]u8 = null;
threadlocal var fixed_allocator: ?std.heap.FixedBufferAllocator = null;

fn init_fixed_allocator() std.heap.FixedBufferAllocator {
    if (fixed_allocator) |allocator| {
        return allocator;
    }
    main_buffer = main_allocator.alloc(u8, 512) catch unreachable;
    if (main_buffer) |buf| {
        const alloc = std.heap.FixedBufferAllocator.init(buf);
        fixed_allocator = alloc;
        return alloc;
    } else {
        std.debug.print("Failed to allocate buffer for fixed allocator\n", .{});
        unreachable;
    }
    unreachable;
}
// can be called from c for optimization
export fn grdw_zig_deinit_fixed_allocator() void {
    fixed_allocator = null;
    if (main_buffer) |buffer| {
        main_allocator.free(buffer);
    }
    main_buffer = null;
}

const grdw = @cImport({
    @cInclude("gradido_protobuf_zig.h");
    @cInclude("gradido_protobuf_zig.c");
    @cInclude("grdw_basic_types.h");
    @cInclude("grdw_hiero.h");
    @cInclude("grdw_ledger_anchor.h");
    @cInclude("grdw_specific_transactions.h");
    @cInclude("grdw_specific_transactions.c");
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

fn copy_string(src: ?[]const u8) [*c]u8 {
    if (src) |s| {
        if (s.len == 0) {
            return null;
        }
        return grdw.grdu_reserve_copy_string(@ptrCast(s), s.len);
    }
    return null;
}

fn reference_c_string(src: [*c]const u8) []const u8 {
    if (src == null) return "";
    const src_size = grdw.grdu_strlen(src);
    if (src_size == 0) {
        return "";
    }
    return @as([*]const u8, @ptrCast(src))[0..src_size];
}

fn reference_c_bytes(src: [*c]const u8, len: usize) []const u8 {
    return @as([*]const u8, @ptrCast(src))[0..len];
}

fn copy_bytes(src: []const u8) ?[*c]u8 {
    return grdw.grdu_reserve_copy(@ptrCast(src), src.len);
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

fn convertTransferAmount(src: ?gradido.TransferAmount) grdw.grdw_transfer_amount {
    if (src) |s| {
        var result = grdw.grdw_transfer_amount{
            .amount = @intCast(s.amount),
            .community_id = copy_string(s.community_id),
        };
        @memcpy(result.pubkey[0..32], s.pubkey);
        return result;
    }
    return undefined;
}

fn convertGradidoTransfer(src: gradido.GradidoTransfer) grdw.grdw_gradido_transfer {
    var result = grdw.grdw_gradido_transfer{
        .sender = convertTransferAmount(src.sender),
    };
    @memcpy(result.recipient[0..32], src.recipient);
    return result;
}

export fn grdw_confirmed_transaction_decode(tx: *grdw.grdw_confirmed_transaction, data: [*c]const u8, size: usize) c_int {
    var alloc = init_fixed_allocator();
    var arena = std.heap.ArenaAllocator.init(alloc.allocator());
    defer arena.deinit();

    var reader: std.io.Reader = .fixed(data[0..size]);
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
        .version_number = copy_string(decoded_tx.version_number) orelse return -1,
        .balance_derivation = @intCast(@intFromEnum(decoded_tx.balance_derivation)),
        // .ledger_anchor = decoded_tx.ledger_anchor,
        .running_hash = copy_bytes(decoded_tx.running_hash) orelse return -1,
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
            std.debug.print("Body bytes size type overflow: {} Bytes does not fit in u16\n", .{transaction.body_Bytes.len});
            return -1;
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
        tx.*.account_balances[index].community_id = copy_string(account_balance.community_id) orelse null;
        index += 1;
    }
    return @intCast(arena.queryCapacity());
}

export fn grdw_transaction_body_decode(body: *grdw.grdw_transaction_body, data: [*c]const u8, size: usize) c_int {
    var alloc = init_fixed_allocator();
    var arena = std.heap.ArenaAllocator.init(alloc.allocator());
    defer arena.deinit();

    var reader: std.io.Reader = .fixed(data[0..size]);
    const decoded_tx = gradido.TransactionBody.decode(&reader, arena.allocator()) catch |err| {
        std.debug.print("Error decoding transaction: {}\n", .{err});
        return -1;
    };
    body.* = .{
        .memos = null,
        .memos_count = 0,
        .created_at = .{
            .seconds = decoded_tx.created_at.?.seconds,
            .nanos = decoded_tx.created_at.?.nanos,
        },
        .transaction_type = grdw.GRDW_TRANSACTION_TYPE_NONE,
        .version_number = copy_string(decoded_tx.version_number) orelse return -1,
        .type = @intCast(@intFromEnum(decoded_tx.type)),
        .other_group = copy_string(decoded_tx.other_group) orelse null,
        .data = undefined,
    };
    var index: usize = 0;
    // memos
    if (decoded_tx.memos.items.len > 0) {
        grdw.grdw_transaction_body_reserve_memos(body, @intCast(decoded_tx.memos.items.len));
        for (decoded_tx.memos.items) |memo| {
            body.*.memos[index].type = @intCast(@intFromEnum(memo.type));
            body.*.memos[index].memo = copy_bytes(memo.memo) orelse return -1;
            body.*.memos[index].memo_size = @intCast(memo.memo.len);
            index += 1;
        }
    }
    // specific transaction
    if (decoded_tx.data) |body_data| {
        switch (body_data) {
            .transfer => |transfer| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_TRANSFER;
                body.*.data.transfer = grdw.grdw_gradido_transfer_new(convertTransferAmount(transfer.sender), @ptrCast(transfer.recipient));
            },
            .creation => |creation| {
                if (creation.target_date) |target_date| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_CREATION;
                    body.*.data.creation = grdw.grdw_gradido_creation_new(
                        convertTransferAmount(creation.recipient),
                        grdw.grdw_timestamp_seconds{ .seconds = @intCast(target_date.seconds) },
                    );
                } else {
                    std.debug.print("Error decoding transaction: {s}\n", .{"creation.target_date is null"});
                    return -2;
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
                    body.*.data.deferred_transfer = grdw.grdw_gradido_deferred_transfer_new(convertGradidoTransfer(transfer), @intCast(deferred_transfer.timeout_duration.?.seconds));
                } else {
                    std.debug.print("Error decoding transaction: {s}\n", .{"deferred_transfer.transfer is null"});
                    return -3;
                }
            },
            .community_root => |community_root| {
                body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_COMMUNITY_ROOT;
                body.*.data.community_root = grdw.grdw_community_root_new(@ptrCast(community_root.pubkey), @ptrCast(community_root.gmw_pubkey), @ptrCast(community_root.auf_pubkey));
            },
            .redeem_deferred_transfer => |redeem_deferred_transfer| {
                if (redeem_deferred_transfer.transfer) |transfer| {
                    body.*.transaction_type = grdw.GRDW_TRANSACTION_TYPE_REDEEM_DEFERRED_TRANSFER;
                    body.*.data.redeem_deferred_transfer = grdw.grdw_gradido_redeem_deferred_transfer_new(@intCast(redeem_deferred_transfer.deferredTransferTransactionNr), convertGradidoTransfer(transfer));
                } else {
                    std.debug.print("Error decoding transaction: {s}\n", .{"redeem_deferred_transfer.transfer is null"});
                    return -4;
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

export fn grdw_transaction_body_encode(c_body: *const grdw.grdw_transaction_body, data: [*c]u8, size: usize) c_int {
    var alloc = init_fixed_allocator();
    var arena = std.heap.ArenaAllocator.init(alloc.allocator());
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
        body.memos.ensureTotalCapacity(arena.allocator(), c_body.memos_count) catch |err| {
            std.debug.print("Error ensuring memos capacity: {}\n", .{err});
            return -1;
        };
        for (c_body.memos[0..c_body.memos_count]) |memo| {
            body.memos.append(arena.allocator(), .{
                .type = @enumFromInt(memo.type),
                .memo = reference_c_string(memo.memo),
            }) catch |err| {
                std.debug.print("Error appending memo: {}\n", .{err});
                return -2;
            };
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
            std.debug.print("Error decoding transaction: {}\n", .{c_body.transaction_type});
            return -3;
        },
    }

    var c_caller_buffer_alloc = std.heap.FixedBufferAllocator.init(data[0..size]);
    var writer = std.io.Writer.Allocating.init(c_caller_buffer_alloc.allocator());
    body.encode(&writer.writer, arena.allocator()) catch |err| {
        return switch (err) {
            error.OutOfMemory => -4,
            error.WriteFailed => -5,
        };
    };
    return @intCast(writer.writer.buffer.len);
}
