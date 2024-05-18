module opensafe::constants {
    
    const MANAGEMENT_TRANSACTION_KIND: u64 = 0;
    const PROGRAMMABLE_TRANSACTION_KIND: u64 = 1;
    const COINS_TRANSFER_TRANSACTION_KIND: u64 = 2;
    const OBJECTS_TRANSFER_TRANSACTION_KIND: u64 = 3;

    const APPROVED_VOTE_KIND: u64 = 0;
    const REJECTED_VOTE_KIND: u64 = 1;
    const CANCELLED_VOTE_KIND: u64 = 2;

    const TRANSACTION_STATUS_ACTIVE: u64 = 0;
    const TRANSACTION_STATUS_APPROVED: u64 = 1;
    const TRANSACTION_STATUS_REJECTED: u64 = 2;
    const TRANSACTION_STATUS_CANCELLED: u64 = 3;
    const TRANSACTION_STATUS_EXECUTED: u64 = 4;

    const ADD_OWNER_ACTION: u64 = 0;
    const REMOVE_OWNER_ACTION: u64 = 1;
    const CHANGE_THRESHOLD_ACTION: u64 = 2;
    const CHANGE_EXECUTION_DELAY_ACTION: u64 = 3;

    // ===== Transaction kinds =====

    public fun management_transaction_kind(): u64 {
        MANAGEMENT_TRANSACTION_KIND
    }

    public fun programmable_transaction_kind(): u64 {
        PROGRAMMABLE_TRANSACTION_KIND
    }

    public fun coins_transfer_transaction_kind(): u64 {
        COINS_TRANSFER_TRANSACTION_KIND
    }

    public fun objects_transfer_transaction_kind(): u64 {
        OBJECTS_TRANSFER_TRANSACTION_KIND
    }

    // ===== Vote kinds =====
    
    public fun approved_vote_kind(): u64 {
        APPROVED_VOTE_KIND
    }

    public fun rejected_vote_kind(): u64 {
        REJECTED_VOTE_KIND
    }

    public fun cancelled_vote_kind(): u64 {
        CANCELLED_VOTE_KIND
    }

    // ===== Transaction statuses =====

    public fun transaction_status_active(): u64 {
        TRANSACTION_STATUS_ACTIVE
    }

    public fun transaction_status_approved(): u64 {
        TRANSACTION_STATUS_APPROVED
    }

    public fun transaction_status_rejected(): u64 {
        TRANSACTION_STATUS_REJECTED
    }

    public fun transaction_status_cancelled(): u64 {
        TRANSACTION_STATUS_CANCELLED
    }

    public fun transaction_status_executed(): u64 {
        TRANSACTION_STATUS_EXECUTED
    }

    // ===== Transaction Actions =====

    public fun add_owner_action(): u64 {
        ADD_OWNER_ACTION
    }

    public fun remove_owner_action(): u64 {
        REMOVE_OWNER_ACTION
    }

    public fun change_threshold_action(): u64 {
        CHANGE_THRESHOLD_ACTION
    }

    public fun change_execution_delay_action(): u64 {
        CHANGE_EXECUTION_DELAY_ACTION
    }

}