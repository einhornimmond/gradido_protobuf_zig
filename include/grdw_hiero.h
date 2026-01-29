#ifndef GRDW_HIERO_H
#define GRDW_HIERO_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include "grdw_basic_types.h"

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

grdw_hiero_transaction_id* grdw_hiero_transaction_id_new(const grdw_timestamp* transactionValidStart, const grdw_hiero_account_id* accountID);

#ifdef __cplusplus
}
#endif

#endif  /* GRDW_HIERO_H */