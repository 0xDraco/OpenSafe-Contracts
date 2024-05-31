module tonal::lock_map {
    use sui::table::{Self, Table};

    use tonal::transaction::{SecureTransaction};

    /// This represents a shared object that keep track of safe objects that are being used (or will be used) in a transaction.
    /// This helps us avoid removing or transferring an object that is scheduled to be used in a transction.
    public struct LockMap has key {
        id: UID,
        safe: ID,
        object_transaction: Table<ID, u64>,
        transaction_objects: Table<u64, vector<ID>>
    }

    public(package) fun new(safe: ID, ctx: &mut TxContext): LockMap {
        LockMap {
            id: object::new(ctx),
            safe,
            object_transaction: table::new(ctx),
            transaction_objects: table::new(ctx)
        }
    }

    // public fun lock_transaction_objects(lock_map: &mut LockMap, transaction: &mut SecureTransaction, objects: vector<ID>) {
    //     let transaction_index = transaction.inner().index();
    //     assert!(!lock_map.transaction_objects.contains(transaction_index), ETransactionLocksDuplicate);
    //     lock_map.transaction_objects.add(transaction_index, objects);

    //     let mut i = 0;
    //     while(i <  objects.length()) {
    //         let object = objects[i];
    //         if(lock_map.object_transaction.contains(object)) {
    //             let transaction = lock_map.object_transaction[object];
    //             assert!(transaction <= self.last_stale_transaction, EObjectIsLocked);

    //             lock_map.object_transaction.remove(object);
    //         };

    //         lock_map.object_transaction.add(object, transaction_index);
    //         i = i + 1;
    //     };
    // }

    // public fun unlock_transaction_objects(lock_map: &mut LockMap, transaction: &SecureTransaction, ctx: &TxContext) {
    //     let transaction_index = transaction.inner().index();
    //     assert!(lock_map.transaction_objects.contains(transaction_index), ETransactionLockNotFound);
    //     let mut objects = lock_map.transaction_objects.remove(transaction_index);

    //     while(!objects.is_empty()) {
    //         let object = objects.pop_back();
    //         assert!(
    //             transaction_index == lock_map.object_transaction.remove(object),
    //             ELockedTransactionObjectMismatch
    //         );
    //     }
    // }

    // public fun is_object_usable(self: &LockMap, id: ID): bool {
    //     if(!self.objects_lock_map.object_transaction.contains(id)) return true;
    //     let transaction = self.objects_lock_map.object_transaction[id];
    //     transaction <= self.last_stale_transaction
    // }

    // public fun is_object_locked_for_transaction(self: &Safe, id: ID, transaction: u64): bool {
    //     if(!self.objects_lock_map.object_transaction.contains(id)) return false;
    //     self.objects_lock_map.object_transaction[id] == transaction
    // }

    // public fun get_locked_bjects(self: &Safe, offset: Option<u64>, limit: Option<u64>): (u64, VecMap<u64, vector<ID>>) {
    //     let transactions_count = self.transactions_count();

    //     let offset = offset.destroy_with_default(self.last_stale_transaction + 1);
    //     let limit = limit.destroy_with_default(transactions_count);
    //     assert!(offset <= transactions_count, EInvalidTransactionOffset);

    //     let end = math::min(offset + limit, transactions_count);

    //     let (mut i, mut map) = (offset, vec_map::empty());
    //     while(i < end) {
    //         if(self.objects_lock_map.transaction_objects.contains(i)) {
    //             let locked_objects = self.objects_lock_map.transaction_objects[i];
    //             map.insert(i, locked_objects)
    //         };

    //         i = i + 1;
    //     };

    //     (end, map)
    // }

}