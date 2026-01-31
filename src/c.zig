pub const grdw = @cImport({
    @cInclude("gradido_protobuf_zig.h");
    @cInclude("gradido_protobuf_zig.c");
    @cInclude("grdw_basic_types.h");
    @cInclude("grdw_hiero.h");
    @cInclude("grdw_ledger_anchor.h");
    @cInclude("grdw_specific_transactions.h");
    @cInclude("grdw_specific_transactions.c");
});
