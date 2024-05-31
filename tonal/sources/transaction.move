module tonal::transaction {
    use std::string::String;

    use sui::clock::Clock;
    use sui::vec_map::VecMap;

    use tonal::utils;
    use tonal::constants::{transaction_status_active, transaction_status_approved};

    public struct Transaction has key, store {
        id: UID,
        /// The index of the transaction in the safe.
        index: u64,
        /// The status of the transaction.
        status: u64,
        /// The addresses that approved the transaction.
        approved: vector<address>,
        /// The addresses that rejected the transaction.
        rejected: vector<address>,
        /// The addresses that cancelled the transaction.
        cancelled: vector<address>,
        /// A vector of the bcs encoded transaction actions or instructions.
        payload: vector<vector<u8>>,
        /// Metadata associated with the transaction
        metadata: TransactionMetadata,
        /// The timestamp when the status was last updated.
        last_status_update_ms: u64
    }

    /// This stores extra metadata associated with the transaction. 
    /// These are data not used in the package, but are used on the client.
    public struct TransactionMetadata has store {
        /// The safe threshold at the time of creation
        threshold: u64,
        /// The creator of the transaction.
        creator: address,
        /// The hash of the Sui transaction that executed the transaction.
        hash: Option<vector<u8>>,
        /// Timestamp when transaction was created
        created_at_ms: u64,
        /// Optional key-value pairs that can be used to display information about the transaction.
        display: Option<VecMap<String, String>>
    }

    /// This is used to securely hold transaction for approvals, rejections, cancellation or any other actions.
    public struct SecureTransaction {
        is_stale: bool,
        inner: Transaction,
        safe: SecureTransactionSafe,
        is_execution_delay_expired: bool
    }

    public struct SecureTransactionSafe has drop, store {
        id: ID,
        cutoff: u64,
        threshold: u64,
        stale_index: u64
    }

    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_CANCELLED: u64 = 3;
    const STATUS_EXECUTED: u64 = 4;

    const ETransactionIsStale: u64 = 0;
    const EEmptyTransactionData: u64 = 1;
    const EInvalidTransactionStatus: u64 = 2;
    const EAlreadyApprovedTransaction: u64 = 4;
    const EAlreadyRejectedTransaction: u64 = 5;
    const EAlreadyCancelledTransaction: u64 = 6;

    // Creates a new Safe transaction.
    public(package) fun new(index: u64, threshold: u64, payload: vector<vector<u8>>, clock: &Clock, ctx: &mut TxContext): Transaction {
        assert!(!payload.is_empty(), EEmptyTransactionData);

        let metadata = new_metadata(threshold, ctx.sender(), clock.timestamp_ms());
        let transaction = Transaction {
            id: object::new(ctx),
            index,
            payload,
            metadata,
            status: STATUS_ACTIVE,
            approved: vector::empty(),
            rejected: vector::empty(),
            cancelled: vector::empty(),
            last_status_update_ms: clock.timestamp_ms(),
        };

        transaction
    }

    public(package) fun into_secure(
        self: Transaction,
        safe: ID,
        threshold: u64,
        cutoff: u64,
        stale_index: u64,
        is_stale: bool,
        is_execution_delay_expired: bool
    ): SecureTransaction {
        let safe = SecureTransactionSafe { 
            id: safe, 
            threshold, 
            cutoff,
            stale_index 
        };

        SecureTransaction {
            safe,
            is_stale,
            inner: self,
            is_execution_delay_expired
        }
    }

    public(package) fun into_inner(self: SecureTransaction): Transaction {
        let SecureTransaction { inner, safe: _, is_stale: _, is_execution_delay_expired: _ } = self;
        inner
    }

    // Initializes a new transaction metadata struct
    fun new_metadata(threshold: u64, creator: address, timestamp_ms: u64): TransactionMetadata {
        TransactionMetadata {
            creator,
            threshold,
            hash: option::none(),
            display: option::none(),
            created_at_ms: timestamp_ms,
        }
    }

    public fun set_display_metadata(self: &mut SecureTransaction, display: vector<u8>) {
        self.inner.metadata.display.fill(utils::json_to_vec_map(display))
    }

    public fun approve(self: &mut SecureTransaction, clock: &Clock, ctx: &TxContext) {
        assert!(!self.is_stale, ETransactionIsStale);
        assert!(self.inner.status == transaction_status_active(), EInvalidTransactionStatus);

        let owner = ctx.sender();
        assert!(!self.inner.find_approved(owner).is_some(), EAlreadyApprovedTransaction);

        let rejected = self.inner.find_rejected(owner);
        if(rejected.is_some()) {
            self.inner.rejected.remove(rejected.destroy_some());
        };

        self.inner.approved.push_back(owner);
        if(self.inner.approved.length() >= self.safe.threshold) {
            self.inner.status = STATUS_APPROVED;
            self.inner.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun reject(self: &mut SecureTransaction, clock: &Clock, ctx: &TxContext) {
        assert!(!self.is_stale, ETransactionIsStale);
        assert!(self.inner.status == transaction_status_active(), EInvalidTransactionStatus);

        let owner = ctx.sender();
        assert!(!self.inner.find_rejected(owner).is_some(), EAlreadyRejectedTransaction);

        let approved = self.inner.find_approved(owner);
        if(approved.is_some()) {
            self.inner.approved.remove(approved.destroy_some());
        };

        self.inner.rejected.push_back(owner);
        if(self.inner.rejected.length() >= self.safe.cutoff) {
            self.inner.status = STATUS_REJECTED;
            self.inner.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun cancel(self: &mut SecureTransaction, clock: &Clock, ctx: &TxContext) {
        assert!(self.inner.status == transaction_status_approved(), EInvalidTransactionStatus);
        
        let owner = ctx.sender();
        assert!(!self.inner.find_cancelled(owner).is_some(), EAlreadyCancelledTransaction);

        self.inner.cancelled.push_back(owner);
        if(self.inner.cancelled.length() >= self.safe.threshold) {
            self.inner.status = STATUS_CANCELLED;
            self.inner.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public(package) fun complete(self: &mut SecureTransaction, clock: &Clock, ctx: &TxContext) {
        self.inner.status = STATUS_EXECUTED;
        self.inner.last_status_update_ms = clock.timestamp_ms();
        self.inner.metadata.hash.fill(*ctx.digest());
    }

    /// ===== Getter functions =====

    public fun last_status_update_ms(self: &Transaction): u64 {
        self.last_status_update_ms
    }

    public fun creator(self: &Transaction): address {
        self.metadata.creator
    }

    public fun status(self: &Transaction): u64 {
        self.status
    }

    public fun index(self: &Transaction): u64 {
        self.index
    }

    public fun hash(self: &Transaction): &Option<vector<u8>> {
        &self.metadata.hash
    }

    public fun payload(self: &Transaction): &vector<vector<u8>> {
        &self.payload
    }

    /// ===== Helper functions =====

    public fun find_rejected(self: &Transaction, owner: address): Option<u64> {
        let (mut i, len) = (0, self.rejected.length());
        while (i < len) {
            if (owner == self.rejected[i]) {
                return option::some(i)
            };

            i = i + 1;
        };

        option::none()
    }

    public fun find_approved(self: &Transaction, owner: address): Option<u64> {
        let (mut i, len) = (0, self.approved.length());
        while (i < len) {
            if (owner == self.approved[i]) {
                return option::some(i)
            };

            i = i + 1;
        };

        option::none()
    }

    public fun find_cancelled(self: &Transaction, owner: address): Option<u64> {
        let (mut i, len) = (0, self.cancelled.length());
        while (i < len) {
            if (owner == self.cancelled[i]) {
                return option::some(i)
            };

            i = i + 1;
        };

        option::none()
    }

    public fun id(self: &Transaction): ID {
        self.id.to_inner()
    }

    public fun inner(self: &SecureTransaction): &Transaction {
        &self.inner
    }
}