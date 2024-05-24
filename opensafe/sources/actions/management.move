module opensafe::management {
    use sui::bcs;

    use opensafe::safe::Safe;
    use opensafe::executor::Executable;

    public fun execute(safe: &mut Safe, executable: Executable, ctx: &mut TxContext) {
        let (kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);

        if(kind == 0) {
            safe.add_owner(bcs.peel_address(), ctx);
        } else if(kind == 1) {
            safe.remove_owner(bcs.peel_address());
        } else if(kind == 2) {
            safe.set_threshold(bcs.peel_u64());
        } else if(kind == 3) {
            safe.set_execution_delay_ms(bcs.peel_u64());
        } else {
            abort 0
        };

        assert!(bcs.into_remainder_bytes().is_empty(), 1);
    }

    public fun batch_execute(safe: &mut Safe, executables: &mut vector<Executable>, ctx: &mut TxContext) {
        execute(safe, executables.pop_back(), ctx);
    }

    public fun multi_execute(safe: &mut Safe, mut executables: vector<Executable>, ctx: &mut TxContext) {
        while(!executables.is_empty()) {
            execute(safe, executables.pop_back(), ctx);
        };

       executables.destroy_empty();
    }
}