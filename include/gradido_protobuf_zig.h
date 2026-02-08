#ifndef GRADIDO_PROTOBUF_ZIG_H
#define GRADIDO_PROTOBUF_ZIG_H

#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "grdu_memory.h"
#include "grdw_basic_types.h"
#include "grdw_hiero.h"
#include "grdw_ledger_anchor.h"
#include "grdw_specific_transactions.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
		//! Invalid or Empty Transaction
		GRDW_TRANSACTION_TYPE_NONE = 0,
		//! Creation Transaction, creates new Gradidos
		GRDW_TRANSACTION_TYPE_CREATION = 1,
		//! Transfer Transaction, move Gradidos from one account to another
		GRDW_TRANSACTION_TYPE_TRANSFER = 2,
		//! Group Friends Update Transaction, update relationship between groups
		GRDW_TRANSACTION_TYPE_COMMUNITY_FRIENDS_UPDATE = 3,
		//! Register new address or sub address to group or move addres to another group
		GRDW_TRANSACTION_TYPE_REGISTER_ADDRESS = 4,
		//! Special Transfer Transaction with timeout used for Gradido Link
		GRDW_TRANSACTION_TYPE_DEFERRED_TRANSFER = 5,
		//! First Transaction in Blockchain
		GRDW_TRANSACTION_TYPE_COMMUNITY_ROOT = 6,
		//! redeeming deferred transfer
		GRDW_TRANSACTION_TYPE_REDEEM_DEFERRED_TRANSFER = 7,
		//! timeout deferred transfer, send back locked gdds
		GRDW_TRANSACTION_TYPE_TIMEOUT_DEFERRED_TRANSFER = 8,

		//! technial type for using it in for loops, as max index
		GRDW_TRANSACTION_TYPE_MAX_VALUE = 9
} grdw_transaction_type;

typedef enum {
  GRDW_TRANSACTION_BODY_CROSS_GROUP_TYPE_LOCAL = 0,
  GRDW_TRANSACTION_BODY_CROSS_GROUP_TYPE_INBOUND = 1,
  GRDW_TRANSACTION_BODY_CROSS_GROUP_TYPE_OUTBOUND = 2,
  GRDW_TRANSACTION_BODY_CROSS_GROUP_TYPE_CROSS = 3
} grdw_transaction_body_cross_group_type;

typedef struct grdw_transaction_body {
  grdw_encrypted_memo *memos;
  char *other_group;
  char *version_number;
  grdw_timestamp created_at; 
  union {
    grdw_gradido_transfer *transfer;
    grdw_gradido_creation *creation;
    grdw_community_friends_update *community_friends_update;
    grdw_register_address *register_address;
    grdw_gradido_deferred_transfer *deferred_transfer;
    grdw_community_root *community_root;
    grdw_gradido_redeem_deferred_transfer *redeem_deferred_transfer;
    grdw_gradido_timeout_deferred_transfer *timeout_deferred_transfer;
  } data;
  uint8_t memos_count;  
  grdw_transaction_body_cross_group_type type;
  grdw_transaction_type transaction_type;     
} grdw_transaction_body;

void grdw_transaction_body_reserve_memos(grdu_memory* allocator,grdw_transaction_body* body, size_t memos_count);

typedef enum {
  GRDW_BALANCE_DERIVATION_UNSPECIFIED = 0,
  GRDW_BALANCE_DERIVATION_NODE = 1,
  GRDW_BALANCE_DERIVATION_EXTERN = 2
} grdw_balance_derivation;


typedef struct grdw_gradido_transaction {
  grdw_signature_pair *sig_map;
  uint8_t *body_bytes;
  grdw_ledger_anchor pairing_ledger_anchor;
  uint8_t sig_map_count;
  uint16_t body_bytes_size;
} grdw_gradido_transaction;

void grdw_gradido_transaction_reserve_sig_map(grdu_memory* allocator, grdw_gradido_transaction* tx, uint8_t sig_map_count);
void grdw_gradido_transaction_set_body_bytes(grdu_memory* allocator, grdw_gradido_transaction* tx, const uint8_t* body_bytes, size_t body_bytes_size);

typedef struct grdw_confirmed_transaction {
  uint64_t id;
  grdw_gradido_transaction transaction;
  grdw_timestamp confirmed_at;
  char* version_number;
  uint8_t* running_hash; // 
  grdw_ledger_anchor ledger_anchor;  
  grdw_account_balance* account_balances;
  uint8_t account_balances_count;  
  grdw_balance_derivation balance_derivation;
} grdw_confirmed_transaction;

void grdw_confirmed_transaction_reserve_account_balances(grdu_memory* allocator, grdw_confirmed_transaction* tx, uint8_t account_balances_count);

// utils
char* grdu_reserve_copy_string(grdu_memory* allocator, const char* src, size_t size);
uint8_t* grdu_reserve_copy(grdu_memory* allocator, const uint8_t* src, size_t size);
size_t grdu_strlen(const char* src);

// helper for performance optimization and error reporting
typedef enum {
  GRDW_ENCODING_ERROR_SUCCESS = 0,
  GRDW_ENCODING_ERROR_END_OF_STREAM = -1,
  GRDW_ENCODING_ERROR_UNKNOWN_TRANSACTION_TYPE = -2,
  GRDW_ENCODING_ERROR_BODY_BYTES_SIZE_TYPE_OVERFLOW = -3,
  GRDW_ENCODING_ERROR_CREATION_TARGET_DATE_IS_NULL = -4,
  GRDW_ENCODING_ERROR_DEFERRED_TRANSFER_TRANSFER_IS_NULL = -5,
  GRDW_ENCODING_ERROR_INVALID_BYTES_LENGTH = -6,
  GRDW_ENCODING_ERROR_INVALID_INPUT = -7,
  GRDW_ENCODING_ERROR_NOT_ENOUGH_DATA = -8,
  GRDW_ENCODING_ERROR_OUT_OF_MEMORY = -9,
  GRDW_ENCODING_ERROR_C_ALLOC_FAILED = -10,
  GRDW_ENCODING_ERROR_READ_FAILED = -11,
  GRDW_ENCODING_ERROR_REDEEM_DEFERRED_TRANSFER_TRANSFER_IS_NULL = -12,
  GRDW_ENCODING_ERROR_TRANSFER_AMOUNT_IS_NULL = -13,
  GRDW_ENCODING_ERROR_UNKNOWN_ANCHOR_ID_CASE = -14,
  GRDW_ENCODING_ERROR_WRITE_FAILED = -15,
  GRDW_ENCODING_ERROR_UNKNOWN = -16
} grdw_encoding_error;

typedef struct grdw_encode_result {
  int32_t allocator_used; // used bytes in encoding process, needed size for static buffer
  int32_t written; // written bytes in encoding process, needed size for result buffer
  grdw_encoding_error state;
} grdw_encode_result;

// zig will call c functions to malloc for tx pointer, but free must be called from caller
// decode
extern grdw_encode_result grdw_confirmed_transaction_decode(grdu_memory* allocator, grdw_confirmed_transaction* tx, const uint8_t* data, size_t size);
extern grdw_encode_result grdw_gradido_transaction_decode(grdu_memory* allocator, grdw_gradido_transaction* tx, const uint8_t* data, size_t size);
extern grdw_encode_result grdw_transaction_body_decode(grdu_memory* allocator, grdw_transaction_body* body, const uint8_t* data, size_t size);
// encode
extern grdw_encode_result grdw_confirmed_transaction_encode(const grdw_confirmed_transaction* tx, uint8_t* data, size_t size);
extern grdw_encode_result grdw_transaction_body_encode(const grdw_transaction_body* body, uint8_t* data, size_t size);
extern grdw_encode_result grdw_gradido_transaction_encode(const grdw_gradido_transaction* tx, uint8_t* data, size_t size);

#ifdef __cplusplus
}
#endif


#endif // GRADIDO_PROTOBUF_ZIG_H