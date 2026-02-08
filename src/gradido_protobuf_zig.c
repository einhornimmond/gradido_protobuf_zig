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


void grdw_gradido_transaction_reserve_sig_map(grdw_gradido_transaction* tx, uint8_t sig_map_count) {
  tx->sig_map = (grdw_signature_pair*)malloc(sizeof(grdw_signature_pair) * sig_map_count);
  tx->sig_map_count = sig_map_count;
}

void grdw_gradido_transaction_set_body_bytes(grdw_gradido_transaction* tx, const uint8_t* body_bytes, size_t body_bytes_size) {
  tx->body_bytes = (uint8_t*)malloc(sizeof(uint8_t) * body_bytes_size);
  tx->body_bytes_size = body_bytes_size;
  memcpy(tx->body_bytes, body_bytes, body_bytes_size);
}

void grdw_transaction_body_reserve_memos(grdw_transaction_body* body, size_t memos_count) {
  body->memos = (grdw_encrypted_memo*)malloc(sizeof(grdw_encrypted_memo) * memos_count);
  body->memos_count = memos_count;
}

void grdw_confirmed_transaction_reserve_account_balances(grdw_confirmed_transaction* tx, uint8_t account_balances_count) {
  tx->account_balances = (grdw_account_balance*)malloc(sizeof(grdw_account_balance) * account_balances_count);
  tx->account_balances_count = account_balances_count;
}

void grdw_confirmed_transaction_free_deep(grdw_confirmed_transaction* tx) 
{
  if (!tx) return;
  if (tx->version_number) {
    free(tx->version_number);
    tx->version_number = NULL;
  }
  if (tx->running_hash) {
    free(tx->running_hash);
    tx->running_hash = NULL;
  }
  if (tx->account_balances) {
    free(tx->account_balances);
    tx->account_balances = NULL;
  }
  if (tx->transaction.sig_map) {
    free(tx->transaction.sig_map);
    tx->transaction.sig_map = NULL;
  }
  if (tx->transaction.body_bytes) {
    free(tx->transaction.body_bytes);
    tx->transaction.body_bytes = NULL;
  }
}

void grdw_transaction_body_free_deep(grdw_transaction_body* body) {
  if (!body) return;
  if (body->version_number) {
    free(body->version_number);
    body->version_number = NULL;
  }
  if(body->other_group) {
    free(body->other_group);
    body->other_group = NULL;
  }
  if(body->memos) {
    free(body->memos);
    body->memos = NULL;
    body->memos_count = 0;
  }
  switch(body->transaction_type) {
    case GRDW_TRANSACTION_TYPE_CREATION: free(body->data.creation); break;
    case GRDW_TRANSACTION_TYPE_TRANSFER: free(body->data.transfer); break;
    case GRDW_TRANSACTION_TYPE_COMMUNITY_FRIENDS_UPDATE: free(body->data.community_friends_update); break;
    case GRDW_TRANSACTION_TYPE_REGISTER_ADDRESS: free(body->data.register_address); break;
    case GRDW_TRANSACTION_TYPE_DEFERRED_TRANSFER: free(body->data.deferred_transfer); break;
    case GRDW_TRANSACTION_TYPE_COMMUNITY_ROOT: free(body->data.community_root); break;
    case GRDW_TRANSACTION_TYPE_REDEEM_DEFERRED_TRANSFER: free(body->data.redeem_deferred_transfer); break;
    case GRDW_TRANSACTION_TYPE_TIMEOUT_DEFERRED_TRANSFER: free(body->data.timeout_deferred_transfer); break;
    default: break;
  }
  body->transaction_type = GRDW_TRANSACTION_TYPE_NONE;
}

void grdw_gradido_transaction_free_deep(grdw_gradido_transaction* tx)
{
  if (!tx) return;
  if (tx->body_bytes) {
    free(tx->body_bytes);
    tx->body_bytes = NULL;
    tx->body_bytes_size = 0;
  }
  if (tx->sig_map) {
    free(tx->sig_map);
    tx->sig_map = NULL;
    tx->sig_map_count = 0;
  }
}

char* grdu_reserve_copy_string(const char* src, size_t size) {
  char* dst = (char*)malloc(size+1);
  memcpy(dst, src, size);
  dst[size] = '\0';
  return dst;
}

uint8_t* grdu_reserve_copy(const uint8_t* src, size_t size) {
  uint8_t* dst = (uint8_t*)malloc(size);
  memcpy(dst, src, size);
  return dst;
}

size_t grdu_strlen(const char* src) {
  return strlen(src);
}
