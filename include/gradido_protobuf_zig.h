#ifndef GRADIDO_PROTOBUF_ZIG_H
#define GRADIDO_PROTOBUF_ZIG_H

#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct grdw_timestamp {
  int64_t seconds;
  int32_t nanos;
} grdw_timestamp;

// hiero 
typedef struct {
  int64_t shardNum;
  int64_t realmNum;
  int64_t accountNum;
} grdw_hiero_account_id;

typedef struct {
  grdw_timestamp transactionValidStart;
  grdw_hiero_account_id accountID;
} grdw_hiero_transaction_id;

grdw_hiero_transaction_id* grdw_hiero_transaction_id_new(const grdw_timestamp* transactionValidStart, const grdw_hiero_account_id* accountID) {
  grdw_hiero_transaction_id* hiero_transaction_id = (grdw_hiero_transaction_id*)malloc(sizeof(grdw_hiero_transaction_id));
  hiero_transaction_id->transactionValidStart = *transactionValidStart;
  hiero_transaction_id->accountID = *accountID;
  return hiero_transaction_id;
}

typedef enum {
  GRDW_LEDGER_ANCHOR_TYPE_UNSPECIFIED = 0,
  GRDW_LEDGER_ANCHOR_TYPE_IOTA_MESSAGE_ID = 1,
  GRDW_LEDGER_ANCHOR_TYPE_HIERO_TRANSACTION_ID = 2,
  GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_TRANSACTION_ID = 3,
  GRDW_LEDGER_ANCHOR_TYPE_NODE_TRIGGER_TRANSACTION_ID = 4,
  GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_COMMUNITY_ID = 5,
  GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_USER_ID = 6,
  GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_CONTRIBUTION_ID = 7,
  GRDW_LEDGER_ANCHOR_TYPE_LEGACY_GRADIDO_DB_TRANSACTION_LINK_ID = 8
} grdw_ledger_anchor_type;

typedef union {
  uint8_t* iota_message_id;  // 32 Bytes
  grdw_hiero_transaction_id* hiero_transaction_id;  
  uint64_t legacy_transaction_id;
  uint64_t node_trigger_transaction_id;
  uint64_t legacy_community_id;
  uint64_t legacy_user_id;
  uint64_t legacy_contribution_id;
  uint64_t legacy_transaction_link_id;
} grdw_ledger_anchor_id;

typedef struct grdw_ledger_anchor {
  grdw_ledger_anchor_type type;
  grdw_ledger_anchor_id anchor_id;
} grdw_ledger_anchor;

void grdw_ledger_anchor_set_hiero_transaction_id(grdw_ledger_anchor* anchor, grdw_hiero_transaction_id* hiero_transaction_id) {
  anchor->type = GRDW_LEDGER_ANCHOR_TYPE_HIERO_TRANSACTION_ID;
  anchor->anchor_id.hiero_transaction_id = hiero_transaction_id;
}

typedef enum {
  GRDW_BALANCE_DERIVATION_UNSPECIFIED = 0,
  GRDW_BALANCE_DERIVATION_NODE = 1,
  GRDW_BALANCE_DERIVATION_EXTERN = 2
} grdw_balance_derivation;

typedef struct grdw_signature_pair {
  uint8_t public_key[32];
  uint8_t signature[64];
} grdw_signature_pair;

typedef struct grdw_gradido_transaction {
  grdw_signature_pair *sig_map;
  uint8_t *body_bytes;
  grdw_ledger_anchor pairing_ledger_anchor;
  uint8_t sig_map_size;
  uint8_t body_bytes_size;
} grdw_gradido_transaction;

void grdw_gradido_transaction_reserve_sig_map(grdw_gradido_transaction* tx, uint8_t sig_map_size) {
  tx->sig_map = (grdw_signature_pair*)malloc(sizeof(grdw_signature_pair) * sig_map_size);
  tx->sig_map_size = sig_map_size;
}

void grdw_gradido_transaction_set_body_bytes(grdw_gradido_transaction* tx, const uint8_t* body_bytes, size_t body_bytes_size) {
  tx->body_bytes = (uint8_t*)malloc(sizeof(uint8_t) * body_bytes_size);
  tx->body_bytes_size = body_bytes_size;
  memcpy(tx->body_bytes, body_bytes, body_bytes_size);
}

typedef struct grdw_account_balance {
  uint8_t pubkey[32];
  int64_t balance;
  char* community_id;
} grdw_account_balance;

void grdw_account_balance_set_community_id(grdw_account_balance* balance, const char* community_id) {
  balance->community_id = strdup(community_id);
}

typedef struct grdw_confirmed_transaction {
  uint64_t id;
  grdw_gradido_transaction transaction;
  grdw_timestamp confirmed_at;
  char* version_number;
  uint8_t* running_hash; // 
  grdw_ledger_anchor ledger_anchor;  
  grdw_account_balance* account_balances;
  uint8_t account_balances_size;  
  grdw_balance_derivation balance_derivation;
} grdw_confirmed_transaction;

void grdw_confirmed_transaction_set_version_number(grdw_confirmed_transaction* tx, const char* version_number) {
  tx->version_number = strdup(version_number);
}
void grdw_confirmed_transaction_set_running_hash(grdw_confirmed_transaction* tx, const uint8_t* running_hash) {
  tx->running_hash = (uint8_t*)malloc(sizeof(uint8_t) * 32);
  memcpy(tx->running_hash, running_hash, 32);
}
void grdw_confirmed_transaction_reserve_account_balances(grdw_confirmed_transaction* tx, uint8_t account_balances_size) {
  tx->account_balances = (grdw_account_balance*)malloc(sizeof(grdw_account_balance) * account_balances_size);
  tx->account_balances_size = account_balances_size;
}

void grdw_confirmed_transaction_free_deep(grdw_confirmed_transaction* tx) {
  free(tx->version_number);
  free(tx->running_hash);
  free(tx->account_balances);
  free(tx->transaction.sig_map);
  free(tx->transaction.body_bytes);
}
// zig will call c functions to malloc for tx pointer, but free must be called from caller
extern int grdw_confirmed_transaction_decode(grdw_confirmed_transaction* tx, const uint8_t* data, size_t size);

#ifdef __cplusplus
}
#endif


#endif // GRADIDO_PROTOBUF_ZIG_H