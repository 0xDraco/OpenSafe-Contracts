module tonal::self {
    use sui::table::{Self, Table};

    use tonal::transaction::SecureTransaction;

    /// This represents a shared object that keep track of safe objects that are being used (or will be used) in a transaction.
    /// This helps us avoid removing or transferring an object that is scheduled to be used in a transction.
    public struct LockMap has key {
        id: UID,
        safe: ID,
        object_transaction: Table<ID, u64>,
        transaction_objects: Table<u64, vector<ID>>
    }

    const EObjectIsLocked: u64 = 0;
    const ETransactionLocksDuplicate: u64 = 1;
    const ETransactionLockNotFound: u64 = 2;
    const ELockedTransactionObjectMismatch: u64 = 3;
    const ESafeLockMapMismatch: u64 = 4;

    public(package) fun new(safe: ID, ctx: &mut TxContext): LockMap {
        LockMap {
            id: object::new(ctx),
            safe,
            object_transaction: table::new(ctx),
            transaction_objects: table::new(ctx)
        }
    }

    public fun lock_transaction_objects(self: &mut LockMap, transaction: &mut SecureTransaction, objects: vector<ID>) {
        assert!(self.safe == transaction.safe().id(), ESafeLockMapMismatch);
        let transaction_index = transaction.inner().index();
        assert!(!self.transaction_objects.contains(transaction_index), ETransactionLocksDuplicate);
        self.transaction_objects.add(transaction_index, objects);

        let mut i = 0;
        while(i <  objects.length()) {
            let object = objects[i];
            if(self.object_transaction.contains(object)) {
                let object_transaction = self.object_transaction[object];
                assert!(object_transaction <= transaction.safe().stale_index(), EObjectIsLocked);

                self.object_transaction.remove(object);
            };

            self.object_transaction.add(object, transaction_index);
            i = i + 1;
        };
    }

    public fun unlock_transaction_objects(self: &mut LockMap, transaction: &SecureTransaction) {
        assert!(self.safe == transaction.safe().id(), ESafeLockMapMismatch);
        let transaction_index = transaction.inner().index();
        assert!(self.transaction_objects.contains(transaction_index), ETransactionLockNotFound);
        let mut objects = self.transaction_objects.remove(transaction_index);

        while(!objects.is_empty()) {
            let object = objects.pop_back();
            assert!(
                transaction_index == self.object_transaction.remove(object),
                ELockedTransactionObjectMismatch
            );
        }
    }

    public fun is_object_locked_for_transaction(self: &LockMap, id: ID, transaction: u64): bool {
        if(!self.object_transaction.contains(id)) return false;
        self.object_transaction[id] == transaction
    }

    // public fun get_locked_bjects(self: &LockMap, offset: Option<u64>, limit: Option<u64>): (u64, VecMap<u64, vector<ID>>) {
    //     let transactions_count = self.transactions_count();

    //     let offset = offset.destroy_with_default(self.last_stale_transaction + 1);
    //     let limit = limit.destroy_with_default(transactions_count);
    //     assert!(offset <= transactions_count, EInvalidTransactionOffset);

    //     let end = math::min(offset + limit, transactions_count);

    //     let (mut i, mut map) = (offset, vec_map::empty());
    //     while(i < end) {
    //         if(self.transaction_objects.contains(i)) {
    //             let locked_objects = self.transaction_objects[i];
    //             map.insert(i, locked_objects)
    //         };

    //         i = i + 1;
    //     };

    //     (end, map)
    // }
}