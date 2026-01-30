#ifndef GRDW_SPECIFIC_TRANSACTIONS_H
#define GRDW_SPECIFIC_TRANSACTIONS_H

#include <stdbool.h>

#include "grdw_basic_types.h"
#include "grdw_hiero.h"
#include "grdw_ledger_anchor.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct grdw_community_friends_update {
    bool color_fusion;
} grdw_community_friends_update;

grdw_community_friends_update* grdw_community_friends_update_new(bool color_fusion);

typedef struct grdw_community_root {
    uint8_t pubkey[32];
    uint8_t gmw_pubkey[32];
    uint8_t auf_pubkey[32];
} grdw_community_root;

grdw_community_root* grdw_community_root_new(const uint8_t* pubkey, const uint8_t* gmw_pubkey, const uint8_t* auf_pubkey);

typedef struct grdw_gradido_creation {
    grdw_transfer_amount recipient;
    grdw_timestamp_seconds target_date;
} grdw_gradido_creation;

grdw_gradido_creation* grdw_gradido_creation_new(grdw_transfer_amount recipient, grdw_timestamp_seconds target_date);

typedef struct grdw_gradido_transfer {
    grdw_transfer_amount sender;
    uint8_t recipient[32];
} grdw_gradido_transfer;

grdw_gradido_transfer* grdw_gradido_transfer_new(grdw_transfer_amount sender, const uint8_t* recipient);

typedef struct grdw_gradido_deferred_transfer {
    grdw_gradido_transfer transfer;
    uint32_t timeout_duration;
} grdw_gradido_deferred_transfer;

grdw_gradido_deferred_transfer* grdw_gradido_deferred_transfer_new(grdw_gradido_transfer transfer, uint32_t timeout_duration);

typedef struct grdw_gradido_redeem_deferred_transfer {
    uint64_t deferred_transfer_transaction_nr;
    grdw_gradido_transfer transfer;
} grdw_gradido_redeem_deferred_transfer;

grdw_gradido_redeem_deferred_transfer* grdw_gradido_redeem_deferred_transfer_new(uint64_t deferred_transfer_transaction_nr, grdw_gradido_transfer transfer);

typedef struct grdw_gradido_timeout_deferred_transfer {
    uint64_t deferred_transfer_transaction_nr;
} grdw_gradido_timeout_deferred_transfer;

grdw_gradido_timeout_deferred_transfer* grdw_gradido_timeout_deferred_transfer_new(uint64_t deferred_transfer_transaction_nr);

// group founder must be first registering his root address,
// the same which he used signing the global group add transaction
typedef enum grdw_address_type {
    GRDW_ADDRESS_TYPE_NONE = 0,
    GRDW_ADDRESS_TYPE_COMMUNITY_HUMAN = 1,
    GRDW_ADDRESS_TYPE_COMMUNITY_GMW = 2,
    GRDW_ADDRESS_TYPE_COMMUNITY_AUF = 3,
    GRDW_ADDRESS_TYPE_COMMUNITY_PROJECT = 4,
    GRDW_ADDRESS_TYPE_SUBACCOUNT = 5,
    GRDW_ADDRESS_TYPE_CRYPTO_ACCOUNT = 6
} grdw_address_type;

typedef struct grdw_register_address {
    uint8_t user_pubkey[32];
    grdw_address_type address_type;
    uint32_t derivation_index;
    uint8_t name_hash[32];
    uint8_t account_pubkey[32];    
} grdw_register_address;

grdw_register_address* grdw_register_address_new(const uint8_t* user_pubkey, grdw_address_type address_type, const uint8_t* name_hash, const uint8_t* account_pubkey, uint32_t derivation_index);

#ifdef __cplusplus
}
#endif


#endif // GRDW_SPECIFIC_TRANSACTIONS_H