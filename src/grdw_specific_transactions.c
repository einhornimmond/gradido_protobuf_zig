#include "../include/grdw_specific_transactions.h"

grdw_community_friends_update* grdw_community_friends_update_new(bool color_fusion) {
    grdw_community_friends_update* update = (grdw_community_friends_update*)malloc(sizeof(grdw_community_friends_update));
    update->color_fusion = color_fusion;
    return update;
}

grdw_community_root* grdw_community_root_new(const uint8_t* pubkey, const uint8_t* gmw_pubkey, const uint8_t* auf_pubkey) {
    grdw_community_root* root = (grdw_community_root*)malloc(sizeof(grdw_community_root));
    memcpy(root->pubkey, pubkey, 32);
    memcpy(root->gmw_pubkey, gmw_pubkey, 32);
    memcpy(root->auf_pubkey, auf_pubkey, 32);
    return root;
}

grdw_gradido_creation* grdw_gradido_creation_new(grdw_transfer_amount recipient, grdw_timestamp_seconds target_date) {
    grdw_gradido_creation* creation = (grdw_gradido_creation*)malloc(sizeof(grdw_gradido_creation));
    creation->recipient = recipient;
    creation->target_date = target_date;
    return creation;
}

grdw_gradido_transfer* grdw_gradido_transfer_new(grdw_transfer_amount sender, const uint8_t* recipient) {
    grdw_gradido_transfer* transfer = (grdw_gradido_transfer*)malloc(sizeof(grdw_gradido_transfer));
    transfer->sender = sender;
    memcpy(transfer->recipient, recipient, 32);
    return transfer;
}

grdw_gradido_deferred_transfer* grdw_gradido_deferred_transfer_new(grdw_gradido_transfer transfer, uint32_t timeout_duration) {
    grdw_gradido_deferred_transfer* deferred_transfer = (grdw_gradido_deferred_transfer*)malloc(sizeof(grdw_gradido_deferred_transfer));
    deferred_transfer->transfer = transfer;
    deferred_transfer->timeout_duration = timeout_duration;
    return deferred_transfer;
}

grdw_gradido_redeem_deferred_transfer* grdw_gradido_redeem_deferred_transfer_new(uint64_t deferred_transfer_transaction_nr, grdw_gradido_transfer transfer) {
    grdw_gradido_redeem_deferred_transfer* redeem_deferred_transfer = (grdw_gradido_redeem_deferred_transfer*)malloc(sizeof(grdw_gradido_redeem_deferred_transfer));
    redeem_deferred_transfer->deferred_transfer_transaction_nr = deferred_transfer_transaction_nr;
    redeem_deferred_transfer->transfer = transfer;
    return redeem_deferred_transfer;
}

grdw_gradido_timeout_deferred_transfer* grdw_gradido_timeout_deferred_transfer_new(uint64_t deferred_transfer_transaction_nr) {
    grdw_gradido_timeout_deferred_transfer* timeout_deferred_transfer = (grdw_gradido_timeout_deferred_transfer*)malloc(sizeof(grdw_gradido_timeout_deferred_transfer));
    timeout_deferred_transfer->deferred_transfer_transaction_nr = deferred_transfer_transaction_nr;
    return timeout_deferred_transfer;
}

grdw_register_address* grdw_register_address_new(const uint8_t* user_pubkey, grdw_address_type address_type, const uint8_t* name_hash, const uint8_t* account_pubkey, uint32_t derivation_index) {
    grdw_register_address* register_address = (grdw_register_address*)malloc(sizeof(grdw_register_address));
    memcpy(register_address->user_pubkey, user_pubkey, 32);
    register_address->address_type = address_type;
    memcpy(register_address->name_hash, name_hash, 32);
    memcpy(register_address->account_pubkey, account_pubkey, 32);
    register_address->derivation_index = derivation_index;
    return register_address;
}
