
#ifndef GRDW_LEDGER_ANCHOR_H
#define GRDW_LEDGER_ANCHOR_H

#include "gradido_protobuf_zig.h"

#ifdef __cplusplus
extern "C" {
#endif

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

void grdw_ledger_anchor_set_hiero_transaction_id(grdw_ledger_anchor* anchor, grdw_hiero_transaction_id* hiero_transaction_id);

#ifdef __cplusplus
}
#endif  

#endif  /* GRDW_LEDGER_ANCHOR_H */
