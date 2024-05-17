module opensafe::transaction {
    use sui::bcs;
    use sui::clock::Clock;

    use opensafe::safe::{Self, OwnerCap, Safe};
    use opensafe::parser;

    public struct Transaction has key {
        id: UID,
        /// The safe this transaction belongs to.
        safe: ID,
        /// The kind of transaction (e.g. config = 0, programmable = 1).
        kind: u64,
        /// The index of the transaction in the safe.
        index: u64,
        /// The status of the transaction.
        status: u64,
        /// The creator of the transaction.
        creator: address,
        /// The addresses that approved the transaction.
        approved: vector<address>,
        /// The addresses that rejected the transaction.
        rejected: vector<address>,
        /// The addresses that cancelled the transaction.
        cancelled: vector<address>,
        /// This stores information or actions of the transaction in the BCS format.
        /// 
        /// - For config transactions, it stores a list of action data in the BCS format. 
        /// - Object and coin sending transactions follow the same structure.
        /// - For programmable transactions, it contains a list of three parts: transaction inputs variables, inputs, and commands.
        ///   The transaction variables come first in the list, followed by the inputs, and finally, the commands. 
        data: vector<vector<u8>>,
        /// The hash of the Sui transaction that executed the transaction.
        hash: Option<vector<u8>>,
        /// The timestamp when the status was last updated.
        last_status_update_ms: u64,
    }

    // public struct TransactionDisplay has key {
    //     id: UID,
    //     title: String,
    //     transaction: ID,
    //     fields: vector<VecMap<String, vector<u8>>>
    // }


    public struct TransactionExecutionRequest {
        safe: ID,
        transaction: ID,
        /// An ordered list of the operations that have been executed.
        executed_operations: vector<u64>,
    }

    const CONFIG_TRANSACTION_KIND: u64 = 0;
    const PROGRAMMABLE_TRANSACTION_KIND: u64 = 1;
    const COINS_TRANSFER_TRANSACTION_KIND: u64 = 2;
    const OBJECTS_TRANSFER_TRANSACTION_KIND: u64 = 3;

    const APPROVED_VOTE_KIND: u64 = 0;
    const REJECTED_VOTE_KIND: u64 = 1;
    const CANCELLED_VOTE_KIND: u64 = 2;

    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_CANCELLED: u64 = 3;
    const STATUS_EXECUTED: u64 = 4;

    const ADD_OWNER_OPERATION: u64 = 0;
    const REMOVE_OWNER_OPERATION: u64 = 1;
    const CHANGE_THRESHOLD_OPERATION: u64 = 2;
    const CHANGE_EXECUTION_DELAY_OPERATION: u64 = 3;

    const ESafeStorageMismatch: u64 = 0;
    const EInvalidOwnerCap: u64 = 0;
    const EEmptyTransactionData: u64 = 1;
    const EInvalidTransactionData: u64 = 2;
    const EInvalidTransactionKind: u64 = 3;
    const EInvalidTransactionStatus: u64 = 4;
    const ETransactionIsInvalidated: u64 = 5;
    const EAlreadyApprovedTransaction: u64 = 6;
    const EAlreadyRejectedTransaction: u64 = 7;
    const EAlreadyCancelledTransaction: u64 = 8;
    const EInvalidOperationExecution: u64 = 9;
    const EIncompleteOperationExecution: u64 = 10;


    public fun new(
        safe: &mut Safe,
        kind: u64,
        data: vector<vector<u8>>,
        owner_cap: &mut OwnerCap,
        clock: &Clock,
        ctx: &mut TxContext
    ): Transaction {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(!data.is_empty(), EEmptyTransactionData);

        if(kind == CONFIG_TRANSACTION_KIND) { 
            parse_config_transaction(data) 
        } else if(kind == COINS_TRANSFER_TRANSACTION_KIND) {
            // passing true to only validate the data
            parse_coins_transfer(data, true);
        }  else if(kind == OBJECTS_TRANSFER_TRANSACTION_KIND) {
            // passing true to only validate the data
            parse_objects_transfer(data, true);
        } else if(kind == PROGRAMMABLE_TRANSACTION_KIND) {
            assert!(data.length() == 2, EInvalidTransactionData);
        } else {
            abort EInvalidTransactionKind
        };

        let transaction = Transaction {
            id: object::new(ctx),
            kind,
            data,
            safe: safe.id(),
            hash: option::none(),
            creator: ctx.sender(),
            status: STATUS_ACTIVE,
            approved: vector::empty(),
            rejected: vector::empty(),
            cancelled: vector::empty(),
            index: safe.total_transactions(),
            last_status_update_ms: clock.timestamp_ms(),
        };

        safe.add_transaction(transaction.id());
        transaction
    }

    #[allow(lint(share_owned))]
    public fun share(self: Transaction) {
        transfer::share_object(self);
    }

    public fun approve(
        self: &mut Transaction,
        safe: &Safe,
        owner_cap: &mut OwnerCap,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(self.is_active(), EInvalidTransactionStatus);
        assert!(!self.is_invalidated(safe), ETransactionIsInvalidated);

        let owner = ctx.sender();
        assert!(!self.find_approved(owner).is_some(), EAlreadyApprovedTransaction);

        let rejected = self.find_rejected(owner);
        if(rejected.is_some()) {
            self.rejected.remove(rejected.destroy_some());
            safe::decrement_vote_count(owner_cap, REJECTED_VOTE_KIND);
        };

        self.approved.push_back(owner);
        safe::increment_vote_count(owner_cap, APPROVED_VOTE_KIND);
        if(self.approved.length() >= safe.threshold()) {
            self.status = STATUS_APPROVED;
            self.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun reject(
        self: &mut Transaction,
        safe: &Safe,
        owner_cap: &mut OwnerCap,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(self.is_active(), EInvalidTransactionStatus);
        assert!(!self.is_invalidated(safe), ETransactionIsInvalidated);

        let owner = ctx.sender();
        assert!(!self.find_rejected(owner).is_some(), EAlreadyRejectedTransaction);

        let approved = self.find_approved(owner);
        if(approved.is_some()) {
            self.approved.remove(approved.destroy_some());
            safe::decrement_vote_count(owner_cap, APPROVED_VOTE_KIND);
        };

        self.rejected.push_back(owner);
        safe::increment_vote_count(owner_cap, REJECTED_VOTE_KIND);
        if(self.rejected.length() >= safe.cutoff()) {
            self.status = STATUS_REJECTED;
            self.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun cancel(
        self: &mut Transaction,
        safe: &Safe,
        owner_cap: &mut OwnerCap,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(self.is_approved(), EInvalidTransactionStatus);
        
        let owner = ctx.sender();
        assert!(!self.find_cancelled(owner).is_some(), EAlreadyCancelledTransaction);

        self.cancelled.push_back(owner);
        safe::increment_vote_count(owner_cap, CANCELLED_VOTE_KIND);
        if(self.cancelled.length() >= safe.threshold()) {
            self.status = STATUS_CANCELLED;
            self.last_status_update_ms = clock.timestamp_ms();
        }
    }

    public fun add_executed_operation(request: &mut TransactionExecutionRequest, operation: u64) {
       request.executed_operations.push_back(operation);
    }

    public fun execute_programmable(
        self: &mut Transaction,
        request: TransactionExecutionRequest,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let valid_operations = self.data[2];
        let TransactionExecutionRequest { safe:_, transaction: _, executed_operations } = request;

        assert!(valid_operations.length() == executed_operations.length(), EIncompleteOperationExecution);
        
        let (mut i, len) = (0, valid_operations.length());
        while(i < len) {
            assert!(valid_operations[i] as u64 == executed_operations[i], EInvalidOperationExecution);
            i = i + 1;
        };

        self.confirm_execution(clock, ctx);
    }


    public(package) fun confirm_execution(self: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        self.status = STATUS_EXECUTED;
        self.last_status_update_ms = clock.timestamp_ms();
        self.hash.fill(*ctx.digest());
    }

    public(package) fun execute_config_operation(self: &Transaction, safe: &mut Safe, index: u64, ctx: &mut TxContext): u64 {
        let (action, value) = parser::parse_data(self.data[index]);
        let mut bcs = bcs::new(value);

        if(action == ADD_OWNER_OPERATION) {
            safe.add_owner(bcs.peel_address(), ctx);
        } else if(action == REMOVE_OWNER_OPERATION) {
            safe.remove_owner(bcs.peel_address());
        } else if(action == CHANGE_THRESHOLD_OPERATION) {
            safe.set_threshold(bcs.peel_u64());
        } else if(action == CHANGE_EXECUTION_DELAY_OPERATION) {
            safe.set_execution_delay_ms(bcs.peel_u64());
        };

        assert!(bcs.into_remainder_bytes().is_empty(), EInvalidTransactionData);
        action
    }


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
        self.creator
    }

    public fun status(self: &Transaction): u64 {
        self.status
    }

    public fun kind(self: &Transaction): u64 {
        self.kind
    }

    public fun index(self: &Transaction): u64 {
        self.index
    }

    public fun hash(self: &Transaction): &Option<vector<u8>> {
        &self.hash
    }

    public fun data(self: &Transaction): &vector<vector<u8>> {
        &self.data
    }

    /// ===== Helper functions =====

    public fun is_active(self: &Transaction): bool {
        self.status == STATUS_ACTIVE
    }

    public fun is_approved(self: &Transaction): bool {
        self.status == STATUS_APPROVED
    }

    public fun is_rejected(self: &Transaction): bool {
        self.status == STATUS_REJECTED
    }

    public fun is_cancelled(self: &Transaction): bool {
        self.status == STATUS_CANCELLED
    }

    public fun is_executed(self: &Transaction): bool {
        self.status == STATUS_EXECUTED
    }

    public fun is_invalidated(self: &Transaction, safe: &Safe): bool {
        safe.invalidation_index() != 0 && self.index <= safe.invalidation_index()
    }

    public fun is_execution_ready(self: &Transaction, safe: &Safe, clock: &Clock): bool {
        self.is_approved() && !self.is_invalidated(safe) && self.is_execution_delay_expired(safe, clock)
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

    /// ===== Exposing constants =====
    
    /// === Transaction kinds ===
    
    public fun config_transaction_kind(): u64 {
        CONFIG_TRANSACTION_KIND
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

    /// === Vote kinds ===
    
    public fun approved_vote_kind(): u64 {
        APPROVED_VOTE_KIND
    }

    public fun rejected_vote_kind(): u64 {
        REJECTED_VOTE_KIND
    }

    public fun cancelled_vote_kind(): u64 {
        CANCELLED_VOTE_KIND
    }

    /// === Transaction statuses ===
    
    public fun status_active(): u64 {
        STATUS_ACTIVE
    }

    public fun status_approved(): u64 {
        STATUS_APPROVED
    }

    public fun status_rejected(): u64 {
        STATUS_REJECTED
    }

    public fun status_cancelled(): u64 {
        STATUS_CANCELLED
    }

    public fun status_executed(): u64 {
        STATUS_EXECUTED
    }

    /// === Operation kinds ===
    
    public fun add_owner_operation(): u64 {
        ADD_OWNER_OPERATION
    }

    public fun remove_owner_operation(): u64 {
        REMOVE_OWNER_OPERATION
    }

    public fun change_threshold_operation(): u64 {
        CHANGE_THRESHOLD_OPERATION
    }

    public fun change_execution_delay_operation(): u64 {
        CHANGE_EXECUTION_DELAY_OPERATION
    }

    /// ===== Checks & Validation functions =====

    public fun parse_config_transaction(data: vector<vector<u8>>) {
        let (mut i, len) = (0, data.length());

        while(i < len) {
            let (action, value) = parser::parse_data(data[i]);

            if(action == ADD_OWNER_OPERATION || action == REMOVE_OWNER_OPERATION) {
                parser::parse_address(value);
            } else if(action == CHANGE_THRESHOLD_OPERATION) {
                parser::parse_u64(value);
            } else if(action == CHANGE_EXECUTION_DELAY_OPERATION) {
                let execution_delay = parser::parse_u64(value);
                assert!(execution_delay <= safe::max_execution_delay_ms(), EInvalidTransactionData);
            } else {
                abort EInvalidTransactionData
            };

            i = i + 1;
        }
    }

    public fun parse_coins_transfer(data: vector<vector<u8>>, only_validate: bool): (vector<vector<u8>>, vector<address>, vector<u64>) {
        let (mut i, len) = (0, data.length());

        let mut amounts = vector::empty();
        let mut coin_types = vector::empty();
        let mut recipients = vector::empty();

        while(i < len) {
            let (_, value) = parser::parse_data(data[i]);
            let (amount, recipient, coin_type) = parser::parse_coin_transfer_data(value);

            if(!only_validate) {    
                amounts.push_back(amount);
                coin_types.push_back(coin_type);
                recipients.push_back(recipient);
            };
            
            i = i + 1;
        };

        (coin_types, recipients, amounts)
    }

    public fun parse_objects_transfer(data: vector<vector<u8>>, only_validate: bool): (vector<ID>, vector<address>) {
        let (mut i, len) = (0, data.length());

        let mut object_ids = vector::empty();
        let mut recipients = vector::empty();

        while(i < len) {
            let (_, value) = parser::parse_data(data[i]);
            let (id, recipient) = parser::parse_object_transfer_data(value);

            if(!only_validate) {    
                recipients.push_back(recipient);
                object_ids.push_back(object::id_from_address(id));
            };
            
            i = i + 1;
        };

        (object_ids, recipients)
    }

    public fun parse_programmable_transaction(data: vector<vector<u8>>, only_validate: bool): (vector<vector<u8>>, vector<vector<u8>>) {
        let (mut i, len) = (0, data.length());

        let mut inputs = vector::empty();
        let mut operations = vector::empty();

        while(i < len) {
            let (_, value) = parser::parse_data(data[i]);
            let (inps, ops) = parser::parse_programmable_transaction_data(value);

            if(!only_validate) {
                inputs.append(inps);
                operations.append(ops);
            };
            
            i = i + 1;
        };

        (inputs, operations)
    }
}