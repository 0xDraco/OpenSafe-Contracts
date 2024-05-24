module opensafe::objects {
    use sui::transfer::Receiving;

    use opensafe::safe::Safe;

    /// A struct that stores the objects that are withdrawable from a safe.
    public struct Withdrawable has store, drop {
        /// The objects to be withdrawn.
        objects: vector<ID>
    }

    /// A struct that stores the objects that are borrowable from a safe.
    public struct Borrowable has store, drop {
        /// An address that is used to ensure that a returned object belong to this `Borrowable`.
        id: address,
        /// The objects tto be borrowed.
        objects: vector<ID>
    }

    /// A struct with the information of the object that is being borrowed. 
    /// It's a hot potato, so we ensure the object is returned.
    public struct Borrow {
        /// The safe that is borrowing the object. 
        /// This is used to ensure the object is returned to the safe it was borrowed from.
        safe: ID,
        /// The object that is being borrowed.
        object: ID,
        /// Address of the `Borrowable` that this object is borrowed from.
        ref: address, 
    }

    const EObjectNotWithdrawable: u64 = 0;
    const EObjectNotBorrowable: u64 = 1;
    const EWithdrawableBorrowMismatch: u64 = 2;
    const EBorrowObjectMismatch: u64 = 3;

    public(package) fun new_withdrawable(objects: vector<ID>): Withdrawable {
        Withdrawable { objects }
    }

    public(package) fun new_borrowable(objects: vector<ID>, ctx: &mut TxContext): Borrowable {
        Borrowable { id: ctx.fresh_object_address(), objects }
    }

    public fun put_back<T: key + store>(safe: &mut Safe, withdrawable: &mut Borrowable, borrow: Borrow, object: T) {
        let Borrow { ref, safe: safe_id, object: object_id } = borrow;

        assert!(safe_id == safe.id(), EObjectNotBorrowable);
        assert!(withdrawable.id == ref, EWithdrawableBorrowMismatch);
        assert!(object::id(&object) == object_id, EBorrowObjectMismatch);

        withdrawable.objects.push_back(object_id);
        transfer::public_transfer(object, @0x0);
    }
    
    public fun withdraw<T: key + store>(safe: &mut Safe, withdrawable: &mut Withdrawable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (found, i) = withdrawable.objects.index_of(&object::id(&object));

        assert!(found, EObjectNotWithdrawable);
        withdrawable.objects.remove(i);

        object
    }

    public fun borrow<T: key + store>(safe: &mut Safe, borrowable: &mut Borrowable, receiving: Receiving<T>): (T, Borrow) {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (found, i) = borrowable.objects.index_of(&object::id(&object));

        assert!(found, EObjectNotBorrowable);
        borrowable.objects.remove(i);

        let handle = Borrow {
            safe: safe.id(),
            ref: borrowable.id, 
            object: object::id(&object) 
        };

        (object, handle)
    }
}