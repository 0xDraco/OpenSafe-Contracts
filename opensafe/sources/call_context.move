module opensafe::call_context {
    use sui::clock::Clock;

    use opensafe::safe::{Safe, OwnerCap};
    use opensafe::transaction::Transaction;

    public struct CallContext has drop {
        safe: ID,
        caller: address,
        timestamp_ms: u64,
        transaction: Option<ID>,
    }

    const EInvalidOwnerCap: u64 = 0;
    const ESafeTransactionMismatch: u64 = 1;
    const ETransactionAlreadyAdded: u64 = 2;

    public fun new(safe: &Safe, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): CallContext {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);

        CallContext {
            safe: safe.id(),
            caller: ctx.sender(),
            transaction: option::none(),
            timestamp_ms: clock.timestamp_ms()
        }
    }

    public fun add_transaction(self: &mut CallContext, transaction: &Transaction) {
        assert!(self.safe == transaction.safe(), ESafeTransactionMismatch);
        assert!(self.transaction.is_none(), ETransactionAlreadyAdded);

        self.transaction.fill(transaction.id())
    }

    public fun new_with_transaction(safe: &Safe, transaction: &Transaction, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): CallContext {
        let mut context = new(safe, owner_cap, clock, ctx);
        context.add_transaction(transaction);

        context
    }

    // ===== View functions =====

    public fun safe(self: &CallContext): ID {
        self.safe
    }

    public fun caller(self: &CallContext): address {
        self.caller
    }

    public fun timestamp_ms(self: &CallContext): u64 {
        self.timestamp_ms
    }

    public fun transaction(self: &CallContext): Option<ID> {
        self.transaction
    }
}