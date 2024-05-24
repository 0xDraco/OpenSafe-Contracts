module tonal::executor {
    use sui::clock::Clock;

    use tonal::parser;
    use tonal::safe::Safe;
    use tonal::transaction::Transaction;

    public struct Executor {
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

    const EExecutionComplete: u64 = 0;
    const EExecutorTransactionMismatch: u64 = 2;

    public fun new(safe: &Safe, transaction: &Transaction): Executor {
        Executor {
            safe: safe.id(),
            transaction: transaction.id(),
            next_action_index: 0,
        }
    }

    public fun has_next(self: &Executor, transaction: &Transaction): bool {
        self.next_action_index < transaction.payload().length()
    }

    public fun execute_next(self: &mut Executor, transaction: &Transaction): Executable {
        assert!(self.transaction == transaction.id(), EExecutorTransactionMismatch);
        assert!(self.has_next(transaction), EExecutionComplete);
        let action = transaction.payload()[self.next_action_index];
        self.next_action_index = self.next_action_index + 1;

        let (kind, data) = parser::parse_data(action);
        Executable { safe: self.safe, kind, data }
    }

    public fun execute_all(self: &mut Executor, transaction: &Transaction): vector<Executable> {
        let mut executables = vector::empty();
        while(self.has_next(transaction)) {
            executables.push_back(self.execute_next(transaction));
        };

        executables
    }

    public fun commit(self: Executor, transaction: &mut Transaction, clock: &Clock, ctx: &TxContext) {
        let Executor { safe: _, next_action_index, transaction: transaction_id } = self;
        assert!(transaction.id() == transaction_id, EExecutorTransactionMismatch);
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