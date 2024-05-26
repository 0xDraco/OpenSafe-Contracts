module tonal::transfer {
    use sui::bcs;
    use sui::transfer::Receiving;

    use tonal::safe::Safe;
    use tonal::execution::Executable;

    const TRANSFER_OBJECT_KIND: u64 = 0;
    const SHARE_OBJECT_KIND: u64 = 0;
    const FREEZE_OBJECT_KIND: u64 = 0;

    const EObjectIDMismatch: u64 = 0;
    const EInvalidActionKind: u64 = 1;

    #[allow(lint(share_owned))]
    public fun execute<T: key + store>(safe: &mut Safe, executable: Executable, receiving: Receiving<T>) {
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);

        let (kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);
        
        let object_id = bcs.peel_address().to_id();
        assert!(object_id == object::id(&object), EObjectIDMismatch);

        if(kind == TRANSFER_OBJECT_KIND){
            transfer::public_transfer(object, bcs.peel_address())
        } else if(kind == SHARE_OBJECT_KIND){
            transfer::public_share_object(object)
        } else if(kind == FREEZE_OBJECT_KIND){
            transfer::public_freeze_object(object)
        } else {
            abort EInvalidActionKind
        };

        assert!(bcs.into_remainder_bytes().is_empty(), 1);
    }

    public fun batch_execute<T: key + store>(safe: &mut Safe, executables: &mut vector<Executable>, receiving: Receiving<T>) {
        execute(safe, executables.pop_back(), receiving);
    }
}