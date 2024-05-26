module tonal::ownership {
    use sui::transfer::Receiving;

    use tonal::safe::Safe;

    /// This holds the IDs of the objects that are removable from a safe.
    /// The presence of an object's ID here does not necessarily mean that the object will or must be removed from the safe.
    public struct Removable has drop {
        objects: vector<ID>
    }

    /// This holds the IDs of the objects that are borrowable from a safe, and the IDs of the objects that are currently borrowed.
    /// The presence of an object's ID in the `objects` field indicates that the object is available for borrowing.
    /// The presence of an object's ID in the `borrowed` field indicates that the object is currently borrowed, 
    /// and that it is no longer available for borrowing.
    public struct Borrowable {
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
        let (was_borrowed, i) = borrowable.borrowed.index_of(&object::id(&object));
        assert!(was_borrowed, EInvalidBorrowedObject);
        borrowable.borrowed.remove(i);

        transfer::public_transfer(object, safe.get_address());
    }
    
    public fun withdraw<T: key + store>(safe: &mut Safe, removable: &mut Removable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (is_removable, i) = removable.objects.index_of(&object::id(&object));

        assert!(is_removable, EObjectNotRemovable);
        removable.objects.remove(i);
        object
    }

    public fun borrow<T: key + store>(safe: &mut Safe, borrowable: &mut Borrowable, receiving: Receiving<T>): T {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let (is_borrowable, i) = borrowable.objects.index_of(&object::id(&object));

        assert!(is_borrowable, EObjectNotBorrowable);
        borrowable.borrowed.push_back(borrowable.objects.remove(i));

        object
    }

    public fun destroy_borrowable(borrowable: Borrowable) {
        let Borrowable { objects: _, borrowed } = borrowable;
        assert!(borrowed.is_empty(), EBorrowedObjectsNotReturned);
    }
}