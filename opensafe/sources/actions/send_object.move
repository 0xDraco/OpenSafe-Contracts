module opensafe::send_object {
    use sui::bcs;
    use sui::transfer::Receiving;

    use opensafe::safe::Safe;
    use opensafe::executor::Executable;

    public fun execute<T: key + store>(safe: &mut Safe, executable: Executable, receiving: Receiving<T>) {
        let (kind, data) = executable.destroy(safe);
        assert!(kind == 0, 0);

        let mut bcs = bcs::new(data);
        let object_id = bcs.peel_address().to_id();
        let object = transfer::public_receive(safe.uid_mut_inner(), receiving);

        assert!(object_id == object::id(&object), 0);
        assert!(bcs.into_remainder_bytes().is_empty(), 1);
        transfer::public_transfer(object, bcs.peel_address());
    }

    public fun batch_execute<T: key + store>(safe: &mut Safe, executables: &mut vector<Executable>, receiving: Receiving<T>) {
        execute(safe, executables.pop_back(), receiving);
    }
}