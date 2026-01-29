const SignaturePairWire = extern struct {
    var publicKey: [32]u8 = undefined;
    var signature: [64]u8 = undefined;
};

const GradidoTransactionWire = extern struct {
    var sigMap: []SignaturePairWire = undefined;
    var bodyBytes: []u8 = undefined;
    var parentMessageId: []u8 = undefined;
};
