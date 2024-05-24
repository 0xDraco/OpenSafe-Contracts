module tonal::ownership {
    use sui::transfer::Receiving;

    use tonal::safe::Safe;

    /// A struct that stores the objects that are withdrawable from a safe.
    public struct Withdrawable has store {
        /// The objects to be withdrawn.
        objects: vector<ID>
    }

    /// A struct that stores the objects that are borrowable from a safe.
    public struct Borrowable has store {
        /// The objects to be borrowed.
        objects: vector<ID>,
        /// The objects that have been borrowed
        borrowed: vector<ID>
    }

    const EObjectNotWithdrawable: u64 = 0;
    const EObjectNotBorrowable: u64 = 1;
    const EInvalidBorrowedObject: u64 = 2;
    const ENonEmptyWithdrawableObjects: u64 = 3;
    const ENonEmptyBorrowableObjects: u64 = 4;
    const EBorrowedObjectsNotReturned: u64 = 5;

    public(package) fun new_withdrawable(objects: vector<ID>): Withdrawable {
        Withdrawable { objects }
    }

    public(package) fun new_borrowable(objects: vector<ID>): Borrowable {
        Borrowable {
            objects,
            borrowed: vector::empty()
        }
    }

    public fun put_back<T: key + store>(safe: &mut Safe, borrowable: &mut Borrowable, object: T) {
        let (found, i) = borrowable.borrowed.index_of(&object::id(&object));
        assert!(found, EInvalidBorrowedObject);

        borrowable.borrowed.remove(i);
        transfer::public_transfer(object, safe.get_address());
    }
    
    public fun withdraw<T: key + store>(safe: &mut Safe, withdrawable: &mut Withdrawable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (found, i) = withdrawable.objects.index_of(&object::id(&object));

        assert!(found, EObjectNotWithdrawable);
        withdrawable.objects.remove(i);

        object
    }

    public fun borrow<T: key + store>(safe: &mut Safe, borrowable: &mut Borrowable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (found, i) = borrowable.objects.index_of(&object::id(&object));

        assert!(found, EObjectNotBorrowable);
        borrowable.borrowed.push_back(borrowable.objects.remove(i));

        object
    }

    public fun destroy_empty_withdrawable(withdrawable: Withdrawable) {
        let Withdrawable { objects } = withdrawable;
        assert!(objects.is_empty(), ENonEmptyWithdrawableObjects);
    }

    public fun destroy_empty_borrowable(borrowable: Borrowable) {
        let Borrowable { objects, borrowed } = borrowable;
        assert!(objects.is_empty(), ENonEmptyBorrowableObjects);
        assert!(borrowed.is_empty(), EBorrowedObjectsNotReturned);
    }
}