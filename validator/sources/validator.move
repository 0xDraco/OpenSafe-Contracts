module validator::validator {
    use sui::bcs;
    use sui::dynamic_field as field;
    use sui::transfer::{Self, Receiving};

    use sui_system::sui_system::SuiSystemState;
    use sui_system::validator_cap::UnverifiedValidatorOperationCap;

    use opensafe::safe::{Safe, OwnerCap};
    use opensafe::witness::SafeWitness;

    public struct Key has copy, store, drop { }

    const EInvalidWitness: u64 = 0;
    const EInvalidOwnerCap: u64 = 1;

    public fun register(safe: &mut Safe, system_state: &mut SuiSystemState, cap: UnverifiedValidatorOperationCap, ctx: &mut TxContext) {
        let (_, validator_address) = parse_cap_data(&cap);
        let active_validators = system_state.active_validator_addresses();

        assert!(active_validators.contains(&validator_address), 000);
        
        let uid = safe.extend(&witness);
        
        if(field::exists_(uid, Key {})) {
            let validators = field::borrow_mut<Key, vector<address>>(uid, Key {});
            assert!(!validators.contains(&addr), EInvalidOwnerCap);
            validators.push_back(addr);
        } else {
            field::add(uid, Key {}, vector::singleton(addr));
        }
    }

    public fun unregister(witness: SafeWitness, safe: &mut Safe, addr: address, ctx: &mut TxContext) {
        assert!(witness.safe() == safe.id(), EInvalidWitness);
        // assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);

        let uid = safe.extend(&witness);
        assert!(field::exists_(uid, Key {}), EInvalidOwnerCap);

        let validators = field::borrow_mut<Key, vector<address>>(uid, Key {});
        assert!(validators.contains(&addr), EInvalidOwnerCap);
        // validators.remove(addr);

        
    }

    public fun parse_cap_data(cap: &UnverifiedValidatorOperationCap): (ID, address) {
        let mut bcs = bcs::new(bcs::to_bytes(cap));

        let cap_id = bcs.peel_address().to_id();
        let validator_address = bcs.peel_address();

        assert!(bcs.into_remainder_bytes().is_empty(), 0);
        (cap_id, validator_address)
    }

    // public fun receive_validator_cap(witness: SafeWitness, safe: &mut Safe, receiving: Receiving<UnverifiedValidatorOperationCap>) {
    //     assert!(witness.safe() == safe.id(), EInvalidWitness);
        
    //     let uid = safe.extend(&witness);
    //     let cap = transfer::public_receive(uid, receiving);

    // }

    public fun set_gas_price(safe: &Safe, gas_price: u64, ctx: &mut TxContext) {
    }
}
