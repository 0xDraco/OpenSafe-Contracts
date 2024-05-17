module opensafe::execution {
    use sui::clock::Clock;

    use opensafe::utils;
    use opensafe::parser;
    use opensafe::treasury::Treasury;
    use opensafe::safe::{Safe, OwnerCap};
    use opensafe::transaction::{
        Transaction, 
        
        parse_coins_transfer, 
        parse_objects_transfer, 
        parse_programmable_transaction,

        config_transaction_kind,
        programmable_transaction_kind,
        coins_transfer_transaction_kind, 
        objects_transfer_transaction_kind, 
    };

    public struct SendObjectsExecutionRequest {
        treasury: ID,
        executions_count: u64,
        object_ids: vector<ID>,
        recipients: vector<address>
    }

    public struct SendCoinsExecutionRequest {
        treasury: ID,
        amounts: vector<u64>,
        executions_count: u64,
        recipients: vector<address>,
        coin_types: vector<vector<u8>>
    }

    public struct ProgrammableTransactionExecutionRequest {
        safe: ID,
        transaction: ID,
        inputs: vector<vector<u8>>,
        operations: vector<vector<u8>>,
        executed_operations: vector<u64>
    }

    const EInvalidOwnerCap: u64 = 0;
    const ESafeTreasuryMismatch: u64 = 1;
    const ESafeTransactionMismatch: u64 = 2;
    const ERequestTreasuryMismatch: u64 = 3;
    const ECoinRequestTypeMismatch: u64 = 4;
    const EIncompleteExecutionRequest: u64 = 5;
    const EInvalidTransactionKind: u64 = 6;
    const EInvalidTransactionStatus: u64 = 7;
    const ETransactionIsInvalidated: u64 = 8;
    const ETransactionDelayNotExpired: u64 = 9;

    public fun execute_config_transaction(safe: &mut Safe, transaction: &mut Transaction, owner_cap: &OwnerCap, clock: &Clock, ctx: &mut TxContext) {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert_valid_transaction_execution(safe, transaction, clock);
        assert!(transaction.kind() == config_transaction_kind(), EInvalidTransactionKind);

        let (mut i, len) = (0, transaction.data().length());
        while(i < len) {
            transaction.execute_config_operation(safe, i, ctx);    
            i = i + 1;
        };

        // safe.invalidate_transactions();
        transaction.confirm_execution(clock, ctx);
    }

    public fun request_send_objects_execution(safe: &Safe, transaction: &Transaction, treasury: &Treasury, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): SendObjectsExecutionRequest {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert_valid_treasury_transaction_execution(safe, treasury, transaction, clock);
        assert!(transaction.kind() == objects_transfer_transaction_kind(), EInvalidTransactionKind);

        let (object_ids, recipients) = parse_objects_transfer(*transaction.data(), false);
        
        SendObjectsExecutionRequest {
            object_ids,
            recipients,
            executions_count: 0,
            treasury: treasury.id()
        }
    }

    public fun request_send_coins_execution(safe: &Safe, transaction: &Transaction, treasury: &Treasury, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): SendCoinsExecutionRequest {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert_valid_treasury_transaction_execution(safe, treasury, transaction, clock);
        assert!(transaction.kind() == coins_transfer_transaction_kind(), EInvalidTransactionKind);

        let (coin_types, recipients, amounts) = parse_coins_transfer(*transaction.data(), false);

        SendCoinsExecutionRequest {
            amounts,
            coin_types,
            recipients,
            executions_count: 0,
            treasury: treasury.id()
        }
    }

    public fun request_programmable_transaction_execution(safe: &Safe, transaction: &Transaction, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): ProgrammableTransactionExecutionRequest {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert_valid_transaction_execution(safe, transaction, clock);
        assert!(transaction.kind() == programmable_transaction_kind(), EInvalidTransactionKind);

        let (inputs, operations) = parse_programmable_transaction(*transaction.data(), false);

        ProgrammableTransactionExecutionRequest {
            inputs,
            operations,
            safe: safe.id(),
            transaction: transaction.id(),
            executed_operations: vector::empty()
        }
    }

    public fun send_object<T: key + store>(request: &mut SendObjectsExecutionRequest, treasury: &mut Treasury, index: u64) {
        assert!(request.treasury == treasury.id(), ERequestTreasuryMismatch);
        let object = treasury.withdraw_object<T>(request.object_ids[index]);
        transfer::public_transfer(object, request.recipients[index]);

        request.executions_count = request.executions_count  + 1;
    }

    public fun send_coin<T>(request: &mut SendCoinsExecutionRequest, treasury: &mut Treasury, index: u64, ctx: &mut TxContext) {
        assert!(request.treasury == treasury.id(), ERequestTreasuryMismatch);
        assert!(utils::type_bytes<T>() == request.coin_types[index], ECoinRequestTypeMismatch);

        let coin = treasury.withdraw_coin<T>(request.amounts[index], ctx);
        transfer::public_transfer(coin, request.recipients[index]);

        request.executions_count = request.executions_count  + 1;
    }

    public fun add_executed_operation(request: &mut ProgrammableTransactionExecutionRequest, operation: u64) {
        request.executed_operations.push_back(operation)
    }

    public fun confirm_send_objects_execution_request(request: SendObjectsExecutionRequest, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let SendObjectsExecutionRequest { treasury: _, object_ids, recipients: _, executions_count } = request;
        assert!(object_ids.length() == executions_count,  EIncompleteExecutionRequest);

        transaction.confirm_execution(clock, ctx);
    }

    public fun confirm_send_coins_execution_request(request: SendCoinsExecutionRequest, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let SendCoinsExecutionRequest { treasury: _, coin_types, recipients: _, amounts: _, executions_count } = request;
        assert!(coin_types.length() == executions_count,  EIncompleteExecutionRequest);

        transaction.confirm_execution(clock, ctx);
    }

    public fun confirm_programmable_transaction_execution_request(request: ProgrammableTransactionExecutionRequest, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let ProgrammableTransactionExecutionRequest { safe: _, transaction: _, executed_operations, operations, inputs: _ } = request;
        assert!(operations.length() == executed_operations.length(),  EIncompleteExecutionRequest);

        let mut i = 0;
        while(i < operations.length()) {
            let (op_kind, _) = parser::parse_data(operations[i]);
            assert!(op_kind == executed_operations[i], EIncompleteExecutionRequest);

            i = i + 1;
        };

        transaction.confirm_execution(clock, ctx);
    }

    /// ===== Assertion functions =====
    
    fun assert_valid_treasury_transaction_execution(safe: &Safe, treasury: &Treasury, transaction: &Transaction, clock: &Clock) {
        assert!(safe.id() == treasury.safe(), ESafeTreasuryMismatch);
        assert!(safe.id() == transaction.safe(), ESafeTransactionMismatch);

        assert!(transaction.is_approved(), EInvalidTransactionStatus);
        assert!(!transaction.is_invalidated(safe), ETransactionIsInvalidated);
        assert!(transaction.is_execution_delay_expired(safe, clock), ETransactionDelayNotExpired);
    }

    fun assert_valid_transaction_execution(safe: &Safe, transaction: &Transaction, clock: &Clock) {
        assert!(safe.id() == transaction.safe(), ESafeTransactionMismatch);

        assert!(transaction.is_approved(), EInvalidTransactionStatus);
        assert!(!transaction.is_invalidated(safe), ETransactionIsInvalidated);
        assert!(transaction.is_execution_delay_expired(safe, clock), ETransactionDelayNotExpired);
    }
}