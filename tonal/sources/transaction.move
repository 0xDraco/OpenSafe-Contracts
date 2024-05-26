module tonal::transaction {
    use std::string::String;

    use sui::clock::Clock;
    use sui::vec_map::VecMap;

    use tonal::utils;
    use tonal::safe::Safe;
    use tonal::constants::{transaction_status_active, transaction_status_approved};

    public struct Transaction has key {
        id: UID,
        /// The safe this transaction belongs to.
        safe: ID,
        /// The kind of transaction (e.g. direct = 0, programmable = 1).
        kind: u64,
        /// The status of the transaction.
        status: u64,
        /// The index of the transaction in the safe.
        sequence_number: u64,
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

    // const DIRECT_TRANSACTION_KIND: u64 = 0;
    // const PROGRAMMABLE_TRANSACTION_KIND: u64 = 1;

    // const APPROVED_VOTE_KIND: u64 = 0;
    // const REJECTED_VOTE_KIND: u64 = 1;
    // const CANCELLED_VOTE_KIND: u64 = 2;

    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_CANCELLED: u64 = 3;
    const STATUS_EXECUTED: u64 = 4;

    const EEmptyTransactionData: u64 = 1;
    const EInvalidTransactionStatus: u64 = 2;
    const ETransactionIsVoid: u64 = 3;
    const EAlreadyApprovedTransaction: u64 = 4;
    const EAlreadyRejectedTransaction: u64 = 5;
    const EAlreadyCancelledTransaction: u64 = 6;

    // Creates a new Safe transaction.
    public fun create(safe: &mut Safe, kind: u64, payload: vector<vector<u8>>, clock: &Clock, ctx: &mut TxContext): Transaction {
        safe.assert_sender_owner(ctx);
        assert!(!payload.is_empty(), EEmptyTransactionData);

        // validate_payload(payload, kind);

        let metadata = new_metadata(safe.threshold(), ctx.sender(), clock.timestamp_ms());
        let transaction = new(safe.id(), kind, safe.transactions_count(), payload, metadata, clock.timestamp_ms(), ctx);
        safe.add_transaction(transaction.id());
        transaction
    }

    // Initializes a new transaction object
    fun new(
        safe: ID,
        kind: u64,
        sequence_number: u64,
        payload: vector<vector<u8>>,
        metadata: TransactionMetadata,
        timestamp_ms: u64,
        ctx: &mut TxContext,
    ): Transaction {
        Transaction {
            id: object::new(ctx),
            safe,
            kind,
            payload,
            metadata,
            sequence_number,
            status: STATUS_ACTIVE,
            approved: vector::empty(),
            rejected: vector::empty(),
            cancelled: vector::empty(),
            last_status_update_ms: timestamp_ms,
        }
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

    #[allow(lint(share_owned))]
    public fun share(self: Transaction) {
        transfer::share_object(self);
    }

    public fun add_summary_metadata(self: &mut Transaction, summary: vector<u8>) {
        self.metadata.display.fill(utils::json_to_vec_map(summary))
    }

    public fun approve(self: &mut Transaction, safe: &Safe, clock: &Clock, ctx: &TxContext) {
        safe.assert_sender_owner(ctx);
        assert!(!self.is_stale(safe), ETransactionIsVoid);
        assert!(self.status == transaction_status_active(), EInvalidTransactionStatus);

        let owner = ctx.sender();
        assert!(!self.find_approved(owner).is_some(), EAlreadyApprovedTransaction);

        let rejected = self.find_rejected(owner);
        if(rejected.is_some()) {
            self.rejected.remove(rejected.destroy_some());
        };

        self.approved.push_back(owner);
        if(self.approved.length() >= safe.threshold()) {
            self.status = STATUS_APPROVED;
            self.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun reject(self: &mut Transaction, safe: &Safe, clock: &Clock, ctx: &TxContext) {
        safe.assert_sender_owner(ctx);
        assert!(!self.is_stale(safe), ETransactionIsVoid);
        assert!(self.status == transaction_status_active(), EInvalidTransactionStatus);

        let owner = ctx.sender();
        assert!(!self.find_rejected(owner).is_some(), EAlreadyRejectedTransaction);

        let approved = self.find_approved(owner);
        if(approved.is_some()) {
            self.approved.remove(approved.destroy_some());
        };

        self.rejected.push_back(owner);
        if(self.rejected.length() >= safe.cutoff()) {
            self.status = STATUS_REJECTED;
            self.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun cancel(self: &mut Transaction, safe: &Safe, clock: &Clock, ctx: &TxContext) {
        safe.assert_sender_owner(ctx);
        assert!(self.status == transaction_status_approved(), EInvalidTransactionStatus);
        
        let owner = ctx.sender();
        assert!(!self.find_cancelled(owner).is_some(), EAlreadyCancelledTransaction);

        self.cancelled.push_back(owner);
        if(self.cancelled.length() >= safe.threshold()) {
            self.status = STATUS_CANCELLED;
            self.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public(package) fun confirm_execution(self: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        self.status = STATUS_EXECUTED;
        self.last_status_update_ms = clock.timestamp_ms();
        self.metadata.hash.fill(*ctx.digest());
    }

    // fun validate_payload(payload: vector<vector<u8>>, kind: u64) {
    //     if(kind == CONFIG_TRANSACTION_KIND) { 
    //         parse_config_transaction(payload) 
    //     } else if(kind == COINS_TRANSFER_TRANSACTION_KIND) {
    //         parse_coins_transfer(payload, true);
    //     }  else if(kind == OBJECTS_TRANSFER_TRANSACTION_KIND) {
    //         parse_objects_transfer(payload, true);
    //     } else if(kind == PROGRAMMABLE_TRANSACTION_KIND) {
    //         assert!(payload.length() == 2, EInvalidTransactionData);
    //     } else {
    //         abort EInvalidTransactionKind
    //     };
    // }

    /// ===== Getter functions =====

    public fun id(self: &Transaction): ID {
        object::id(self)
    }

    public fun safe(self: &Transaction): ID {
        self.safe
    }

    public fun last_status_update_ms(self: &Transaction): u64 {
        self.last_status_update_ms
    }

    public fun creator(self: &Transaction): address {
        self.metadata.creator
    }

    public fun status(self: &Transaction): u64 {
        self.status
    }

    public fun kind(self: &Transaction): u64 {
        self.kind
    }

    public fun sequence_number(self: &Transaction): u64 {
        self.sequence_number
    }

    public fun hash(self: &Transaction): &Option<vector<u8>> {
        &self.metadata.hash
    }

    public fun payload(self: &Transaction): &vector<vector<u8>> {
        &self.payload
    }

    /// ===== Helper functions =====

    public fun is_stale(self: &Transaction, safe: &Safe): bool {
        safe.last_stale_transaction() != 0 && self.sequence_number <= safe.last_stale_transaction()
    }

    public fun is_execution_delay_expired(self: &Transaction, safe: &Safe, clock: &Clock): bool {
        clock.timestamp_ms() >= self.last_status_update_ms + safe.execution_delay_ms()
    }

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
}