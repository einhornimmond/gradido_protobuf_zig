#include "../include/gradido_protobuf_zig.h"


grdw_hiero_transaction_id* grdw_hiero_transaction_id_new(const grdw_timestamp* transactionValidStart, const grdw_hiero_account_id* accountID) {
  grdw_hiero_transaction_id* hiero_transaction_id = (grdw_hiero_transaction_id*)malloc(sizeof(grdw_hiero_transaction_id));
  hiero_transaction_id->transactionValidStart = *transactionValidStart;
  hiero_transaction_id->accountID = *accountID;
  return hiero_transaction_id;
}

void grdw_ledger_anchor_set_hiero_transaction_id(grdw_ledger_anchor* anchor, grdw_hiero_transaction_id* hiero_transaction_id) {
  anchor->type = GRDW_LEDGER_ANCHOR_TYPE_HIERO_TRANSACTION_ID;
  anchor->anchor_id.hiero_transaction_id = hiero_transaction_id;
}


void grdw_gradido_transaction_reserve_sig_map(grdw_gradido_transaction* tx, uint8_t sig_map_size) {
  tx->sig_map = (grdw_signature_pair*)malloc(sizeof(grdw_signature_pair) * sig_map_size);
  tx->sig_map_size = sig_map_size;
}

void grdw_gradido_transaction_set_body_bytes(grdw_gradido_transaction* tx, const uint8_t* body_bytes, size_t body_bytes_size) {
  tx->body_bytes = (uint8_t*)malloc(sizeof(uint8_t) * body_bytes_size);
  tx->body_bytes_size = body_bytes_size;
  memcpy(tx->body_bytes, body_bytes, body_bytes_size);
}

void grdw_account_balance_set_community_id(grdw_account_balance* balance, const char* community_id) {
  balance->community_id = strdup(community_id);
}

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
