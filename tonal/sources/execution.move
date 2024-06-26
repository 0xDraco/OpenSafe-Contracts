module tonal::execution {
    use sui::bcs;
    use sui::clock::Clock;

    use tonal::safe::Safe;
    use tonal::constants::{transaction_status_approved};
    use tonal::transaction::{Transaction, SecureTransaction};

    public struct Execution {
        safe: ID,
        transaction_index: u64,
        next_executable_index: u64,
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

    const ETransactionIsStale: u64 = 0;
    const ETransactionNotApproved: u64 = 1;
    const EExecutionDelayNotExpired: u64 = 2;
    const EExecutionComplete: u64 = 3;
    const EExecutionTransactionMismatch: u64 = 4;

    public fun begin(safe: &Safe, transaction: &SecureTransaction, clock: &Clock, ctx: &TxContext): Execution {
        safe.assert_sender_owner(ctx);
        assert!(!safe.is_stale_transaction(transaction.inner()), ETransactionIsStale);
        assert!(safe.is_execution_delay_expired(transaction.inner(), clock), EExecutionDelayNotExpired);
        assert!(transaction.inner().status() == transaction_status_approved(), ETransactionNotApproved);

        Execution {
            safe: safe.id(),
            next_executable_index: 0,
            transaction_index: transaction.inner().index(),
        }
    }

    public fun has_next(self: &Execution, transaction: &Transaction): bool {
        self.next_executable_index < transaction.payload().length()
    }

    public fun next_executable(self: &mut Execution, transaction: &SecureTransaction): Executable {
        assert!(self.transaction_index == transaction.inner().index(), EExecutionTransactionMismatch);
        assert!(self.has_next(transaction.inner()), EExecutionComplete);
        let action = transaction.inner().payload()[self.next_executable_index];
        self.next_executable_index = self.next_executable_index + 1;

        let mut bcs = bcs::new(action);
        let kind = bcs.peel_u64();
        let data = bcs.into_remainder_bytes();

        Executable { safe: self.safe, kind, data }
    }

    public fun all_executables(self: &mut Execution, transaction: &SecureTransaction): vector<Executable> {
        let mut executables = vector::empty();
        while(self.has_next(transaction.inner())) {
            executables.push_back(self.next_executable(transaction));
        };

        executables
    }

    public fun complete(self: Execution, transaction: &mut SecureTransaction, clock: &Clock, ctx: &TxContext) {
        let Execution { safe: _, next_executable_index, transaction_index } = self;
        assert!(transaction.inner().index() == transaction_index, EExecutionTransactionMismatch);
        assert!(next_executable_index == transaction.inner().payload().length(), EExecutionComplete);

        transaction.complete(clock, ctx)
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