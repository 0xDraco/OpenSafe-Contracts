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
        parse_programmable_transaction
    };

    use opensafe::constants::{
        transaction_status_approved,

        management_transaction_kind,
        programmable_transaction_kind,
        coins_transfer_transaction_kind, 
        objects_transfer_transaction_kind
    };

    public struct ObjectsTransfer {
        treasury: ID,
        executions_count: u64,
        object_ids: vector<ID>,
        recipients: vector<address>
    }

    public struct CoinsTransfer {
        treasury: ID,
        amounts: vector<u64>,
        executions_count: u64,
        recipients: vector<address>,
        coin_types: vector<vector<u8>>
    }

    public struct PTBExecution {
        safe: ID,
        transaction: ID,
        inputs: vector<vector<u8>>,
        commands: vector<vector<u8>>
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

    public fun execute_management(safe: &mut Safe, transaction: &mut Transaction, owner_cap: &OwnerCap, clock: &Clock, ctx: &mut TxContext) {
        assert!(transaction.kind() == management_transaction_kind(), EInvalidTransactionKind);
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert_transaction_readiness(safe, transaction, clock);

        let (mut i, len) = (0, transaction.payload().length());
        while(i < len) {
            transaction.execute_config_operation(safe, i, ctx);    
            i = i + 1;
        };

        // safe.invalidate_transactions();
        transaction.confirm_execution(clock, ctx);
    }

    public fun request_objects_transfer(safe: &Safe, transaction: &Transaction, treasury: &Treasury, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): ObjectsTransfer {
        assert!(transaction.kind() == objects_transfer_transaction_kind(), EInvalidTransactionKind);
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(safe.treasury() == treasury.id(), ESafeTreasuryMismatch);
        assert_transaction_readiness(safe, transaction, clock);

        let (object_ids, recipients) = parse_objects_transfer(*transaction.payload(), false);
        
        ObjectsTransfer {
            object_ids,
            recipients,
            executions_count: 0,
            treasury: treasury.id()
        }
    }

    public fun request_coins_transfer(safe: &Safe, transaction: &Transaction, treasury: &Treasury, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): CoinsTransfer {
        assert!(transaction.kind() == coins_transfer_transaction_kind(), EInvalidTransactionKind);
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(safe.treasury() == treasury.id(), ESafeTreasuryMismatch);
        assert_transaction_readiness(safe, transaction, clock);

        let (coin_types, recipients, amounts) = parse_coins_transfer(*transaction.payload(), false);

        CoinsTransfer {
            amounts,
            coin_types,
            recipients,
            executions_count: 0,
            treasury: treasury.id()
        }
    }

    public fun request_ptb_execution(safe: &Safe, transaction: &Transaction, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): PTBExecution {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert_transaction_readiness(safe, transaction, clock);
        assert!(transaction.kind() == programmable_transaction_kind(), EInvalidTransactionKind);

        let (inputs, commands) = parse_programmable_transaction(*transaction.payload(), false);

        PTBExecution {
            inputs,
            commands,
            safe: safe.id(),
            transaction: transaction.id()
        }
    }

    public fun send_object<T: key + store>(request: &mut ObjectsTransfer, treasury: &mut Treasury, index: u64) {
        assert!(request.treasury == treasury.id(), ERequestTreasuryMismatch);
        let object = treasury.withdraw_object<T>(request.object_ids[index]);
        transfer::public_transfer(object, request.recipients[index]);

        request.executions_count = request.executions_count  + 1;
    }

    public fun send_coin<T>(request: &mut CoinsTransfer, treasury: &mut Treasury, index: u64, ctx: &mut TxContext) {
        assert!(request.treasury == treasury.id(), ERequestTreasuryMismatch);
        assert!(utils::type_bytes<T>() == request.coin_types[index], ECoinRequestTypeMismatch);

        let coin = treasury.withdraw_coin<T>(request.amounts[index], ctx);
        transfer::public_transfer(coin, request.recipients[index]);

        request.executions_count = request.executions_count  + 1;
    }

    public fun confirm_send_objects_execution_request(request: ObjectsTransfer, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let ObjectsTransfer { treasury: _, object_ids, recipients: _, executions_count } = request;
        assert!(object_ids.length() == executions_count,  EIncompleteExecutionRequest);

        transaction.confirm_execution(clock, ctx);
    }

    public fun confirm_send_coins_execution_request(request: CoinsTransfer, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let CoinsTransfer { treasury: _, coin_types, recipients: _, amounts: _, executions_count } = request;
        assert!(coin_types.length() == executions_count,  EIncompleteExecutionRequest);

        transaction.confirm_execution(clock, ctx);
    }

    public fun confirm_programmable_transaction_execution_request(request: PTBExecution, transaction: &mut Transaction, clock: &Clock, executed_commands: vector<u64>, ctx: &TxContext) {
        let PTBExecution { safe: _, transaction: _, commands, inputs: _ } = request;
        assert!(commands.length() == executed_commands.length(),  EIncompleteExecutionRequest);

        let mut i = 0;
        while(i < commands.length()) {
            let (command, _) = parser::parse_data(commands[i]);
            assert!(command == executed_commands[i], EIncompleteExecutionRequest);

            i = i + 1;
        };

        transaction.confirm_execution(clock, ctx);
    }

    /// ===== Assertion functions =====

    fun assert_transaction_readiness(safe: &Safe, transaction: &Transaction, clock: &Clock) {
        assert!(safe.id() == transaction.safe(), ESafeTransactionMismatch);

        assert!(transaction.status() == transaction_status_approved(), EInvalidTransactionStatus);
        assert!(!transaction.is_invalidated(safe), ETransactionIsInvalidated);
        assert!(transaction.is_execution_delay_expired(safe, clock), ETransactionDelayNotExpired);
    }
}