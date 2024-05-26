module tonal::validator {
    use sui::bcs;
    use sui::transfer::Receiving;

    use sui_system::sui_system::SuiSystemState;
    use sui_system::validator_cap::UnverifiedValidatorOperationCap;

    use tonal::safe::Safe;
    use tonal::execution::Executable;

    const SET_GAS_PRICE: u64 = 0;
    const REPORT_VALIDATOR: u64 = 1;
    const UNDO_REPORT_VALIDATOR: u64 = 2;
    
    const EInvalidActionKind: u64 = 0;

    public fun execute(safe: &mut Safe, sui_state: &mut SuiSystemState, executable: Executable, receiving: Receiving<UnverifiedValidatorOperationCap>) {
        let (kind, data) = executable.destroy(safe);

        let validator_cap = transfer::public_receive(safe.uid_mut_inner(), receiving);
        let mut bcs = bcs::new(data);

        if(kind == SET_GAS_PRICE){
            sui_state.request_set_gas_price(&validator_cap, bcs.peel_u64())
        } else if(kind == REPORT_VALIDATOR) {
            sui_state.report_validator(&validator_cap, bcs.peel_address()) 
        } else if(kind == UNDO_REPORT_VALIDATOR) {
            sui_state.undo_report_validator(&validator_cap, bcs.peel_address()) 
        } else {
            abort EInvalidActionKind
        };

        transfer::public_transfer(validator_cap, safe.get_address());
        assert!(bcs.into_remainder_bytes().is_empty(), 1);
    }

    public fun batch_execute(safe: &mut Safe, sui_state: &mut SuiSystemState, executables: &mut vector<Executable>, receiving: Receiving<UnverifiedValidatorOperationCap>) {
        execute(safe, sui_state, executables.pop_back(), receiving);
    }
}