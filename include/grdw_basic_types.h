#ifndef GRDW_BASIC_TYPES_H
#define GRDW_BASIC_TYPES_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// basic types
typedef struct grdw_account_balance {
  uint8_t pubkey[32];
  int64_t balance;
  char* community_id;
} grdw_account_balance;

typedef enum {
    SHARED_SECRET = 0,
    COMMUNITY_SECRET = 1,
    PLAIN = 2,
} grdw_memo_key_type;

typedef struct grdw_encrypted_memo {
  grdw_memo_key_type type;
  uint16_t memo_size;
  uint8_t* memo;  
} grdw_encrypted_memo;

typedef struct grdw_signature_pair {
  uint8_t public_key[32];
  uint8_t signature[64];
} grdw_signature_pair;

typedef struct grdw_timestamp {
  int64_t seconds;
  int32_t nanos;
} grdw_timestamp;

typedef struct grdw_timestamp_seconds {
  int64_t seconds;
} grdw_timestamp_seconds;

typedef struct grdw_transfer_amount {
  uint8_t pubkey[32];
  int64_t amount;
  char* community_id;
} grdw_transfer_amount;

#ifdef __cplusplus
}
#endif

#endif  /* GRDW_BASIC_TYPES_H */
