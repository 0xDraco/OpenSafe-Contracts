module tonal::ownership {
    use sui::transfer::Receiving;

    use tonal::safe::Safe;

    /// A struct that stores the objects that are removable from a safe.
    public struct Removable has store {
        objects: vector<ID>
    }

    /// A struct that stores the objects that are borrowable from a safe.
    public struct Borrowable has store {
        objects: vector<ID>,
        borrowed: vector<ID>
    }

    const EObjectNotRemovable: u64 = 0;
    const EObjectNotBorrowable: u64 = 1;
    const EInvalidBorrowedObject: u64 = 2;
    const EBorrowedObjectsNotReturned: u64 = 4;

    public(package) fun new_removable(objects: vector<ID>): Removable {
        Removable { objects }
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
    
    public fun withdraw<T: key + store>(safe: &mut Safe, removable: &mut Removable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (found, i) = removable.objects.index_of(&object::id(&object));

        assert!(found, EObjectNotRemovable);
        removable.objects.remove(i);
        object
    }

    public fun borrow<T: key + store>(safe: &mut Safe, borrowable: &mut Borrowable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (found, i) = borrowable.objects.index_of(&object::id(&object));

        assert!(found, EObjectNotBorrowable);
        borrowable.borrowed.push_back(borrowable.objects.remove(i));

        object
    }

    public fun destroy_removable(removable: Removable) {
        let Removable { objects: _ } = removable;
    }

    public fun destroy_borrowable(borrowable: Borrowable) {
        let Borrowable { objects: _, borrowed } = borrowable;
        assert!(borrowed.is_empty(), EBorrowedObjectsNotReturned);
    }
}