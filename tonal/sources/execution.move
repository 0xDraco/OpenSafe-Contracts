module tonal::execution {
    use sui::bcs;
    use sui::clock::Clock;

    use tonal::safe::Safe;
    use tonal::transaction::Transaction;
    use tonal::constants::{transaction_status_approved};

    public struct Execution {
        safe: ID,
        transaction: ID,
        next_action_index: u64,
    }

    public struct Executable {
        safe: ID,
        kind: u64,
        data: vector<u8>,
    }

    public use fun destroy_executable as Executable.destroy;
    public use fun executable_kind as Executable.kind;
    public use fun executable_data as Executable.data;
    public use fun executable_safe as Executable.safe;

    const ETransactionIsVoid: u64 = 0;
    const ETransactionNotApproved: u64 = 1;
    const EExecutionDelayNotExpired: u64 = 2;
    const EExecutionComplete: u64 = 3;
    const EExecutionTransactionMismatch: u64 = 4;

    public fun begin(safe: &Safe, transaction: &Transaction, clock: &Clock, ctx: &TxContext): Execution {
        safe.assert_sender_owner(ctx);
        assert!(!transaction.is_stale(safe), ETransactionIsVoid);
        assert!(transaction.is_execution_delay_expired(safe, clock), EExecutionDelayNotExpired);
        assert!(transaction.status() == transaction_status_approved(), ETransactionNotApproved);

        Execution {
            safe: safe.id(),
            transaction: transaction.id(),
            next_action_index: 0,
        }
    }

    public fun has_next(self: &Execution, transaction: &Transaction): bool {
        self.next_action_index < transaction.payload().length()
    }

    public fun execute_next(self: &mut Execution, transaction: &Transaction): Executable {
        assert!(self.transaction == transaction.id(), EExecutionTransactionMismatch);
        assert!(self.has_next(transaction), EExecutionComplete);
        let action = transaction.payload()[self.next_action_index];
        self.next_action_index = self.next_action_index + 1;

        let mut bcs = bcs::new(action);
        let kind = bcs.peel_u64();
        let data = bcs.into_remainder_bytes();

        Executable { safe: self.safe, kind, data }
    }

    public fun execute_all(self: &mut Execution, transaction: &Transaction): vector<Executable> {
        let mut executables = vector::empty();
        while(self.has_next(transaction)) {
            executables.push_back(self.execute_next(transaction));
        };

        executables
    }

    public fun complete(self: Execution, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let Execution { safe: _, next_action_index, transaction: transaction_id } = self;
        assert!(transaction.id() == transaction_id, EExecutionTransactionMismatch);
        assert!(next_action_index == transaction.payload().length(), EExecutionComplete);

        transaction.confirm_execution(clock, ctx)
    }

    public(package) fun destroy_executable(executable: Executable, safe: &Safe): (u64, vector<u8>) {
        let Executable { safe: safe_id, kind, data } = executable;
        assert!(safe.id() == safe_id, 0);

        (kind, data)
    }

    public fun executable_kind(executable: &Executable): u64 {
        executable.kind
    }

    public fun executable_data(executable: &Executable): vector<u8> {
        executable.data
    }

    public fun executable_safe(executable: &Executable): ID{
        executable.safe
    }
}