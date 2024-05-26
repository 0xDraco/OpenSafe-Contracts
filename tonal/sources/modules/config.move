module tonal::management {
    use sui::bcs;

    use tonal::safe::Safe;
    use tonal::execution::Executable;

    const ADD_USER_KIND: u64 = 0;
    const REMOVE_USER_KIND: u64 = 1;
    const SET_THRESHOLD_KIND: u64 = 2;
    const SET_EXECUTION_DELAY_KIND: u64 = 3;

    const EInvalidActionKind: u64 = 0;

    public fun execute(safe: &mut Safe, executable: Executable) {
        let (kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);

        if(kind == ADD_USER_KIND) {
            safe.add_owner(bcs.peel_address());
        } else if(kind == REMOVE_USER_KIND) {
            safe.remove_owner(bcs.peel_address());
        } else if(kind == SET_THRESHOLD_KIND) {
            safe.set_threshold(bcs.peel_u64());
        } else if(kind == SET_EXECUTION_DELAY_KIND) {
            safe.set_execution_delay_ms(bcs.peel_u64());
        } else {
            abort EInvalidActionKind
        };

        assert!(bcs.into_remainder_bytes().is_empty(), 1);
    }

    public fun batch_execute(safe: &mut Safe, executables: &mut vector<Executable>) {
        execute(safe, executables.pop_back());
    }

    public fun multi_execute(safe: &mut Safe, mut executables: vector<Executable>) {
        while(!executables.is_empty()) {
            execute(safe, executables.pop_back());
        };

       executables.destroy_empty();
    }
}