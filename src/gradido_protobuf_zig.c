#include "../include/gradido_protobuf_zig.h"


grdw_hiero_transaction_id* grdw_hiero_transaction_id_new(grdu_memory* allocator, const grdw_timestamp* transactionValidStart, const grdw_hiero_account_id* accountID) {
  grdw_hiero_transaction_id* hiero_transaction_id = grdu_memory_alloc(allocator, sizeof(grdw_hiero_transaction_id));
  if(!hiero_transaction_id) return NULL;
  hiero_transaction_id->transactionValidStart = *transactionValidStart;
  hiero_transaction_id->accountID = *accountID;
  return hiero_transaction_id;
}

void grdw_ledger_anchor_set_hiero_transaction_id(grdw_ledger_anchor* anchor, grdw_hiero_transaction_id* hiero_transaction_id) {
  if(!anchor || !hiero_transaction_id) return;
  anchor->type = GRDW_LEDGER_ANCHOR_TYPE_HIERO_TRANSACTION_ID;
  anchor->anchor_id.hiero_transaction_id = hiero_transaction_id;
}


void grdw_gradido_transaction_reserve_sig_map(grdu_memory* allocator, grdw_gradido_transaction* tx, uint8_t sig_map_count) {
  tx->sig_map = (grdw_signature_pair*)grdu_memory_alloc(allocator, sizeof(grdw_signature_pair) * sig_map_count);
  tx->sig_map_count = sig_map_count;
}

void grdw_gradido_transaction_set_body_bytes(grdu_memory* allocator, grdw_gradido_transaction* tx, const uint8_t* body_bytes, size_t body_bytes_size) {
  tx->body_bytes = (uint8_t*)grdu_memory_alloc(allocator, sizeof(uint8_t) * body_bytes_size);
  if (!tx->body_bytes) return;
  tx->body_bytes_size = body_bytes_size;
  memcpy(tx->body_bytes, body_bytes, body_bytes_size);
}

void grdw_transaction_body_reserve_memos(grdu_memory* allocator, grdw_transaction_body* body, size_t memos_count) {
  body->memos = (grdw_encrypted_memo*)grdu_memory_alloc(allocator, sizeof(grdw_encrypted_memo) * memos_count);
  body->memos_count = memos_count;
}

void grdw_confirmed_transaction_reserve_account_balances(grdu_memory* allocator, grdw_confirmed_transaction* tx, uint8_t account_balances_count) {
  tx->account_balances = (grdw_account_balance*)grdu_memory_alloc(allocator, sizeof(grdw_account_balance) * account_balances_count);
  tx->account_balances_count = account_balances_count;
}

char* grdu_reserve_copy_string(grdu_memory* allocator, const char* src, size_t size) {
  char* dst = (char*)grdu_memory_alloc(allocator, size+1);
  if(!dst) return NULL;
  memcpy(dst, src, size);
  dst[size] = '\0';
  return dst;
}

uint8_t* grdu_reserve_copy(grdu_memory* allocator, const uint8_t* src, size_t size) {
  uint8_t* dst = grdu_memory_alloc(allocator, size);
  if(!dst) return NULL;
  memcpy(dst, src, size);
  return dst;
}

size_t grdu_strlen(const char* src) {
  return strlen(src);
}
