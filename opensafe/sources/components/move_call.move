module opensafe::move_call {
    // use std::string::String;

    use sui::bcs;

    use opensafe::safe::Safe;
    use opensafe::executor::Executable;
    use opensafe::utils::addresses_to_ids;
    use opensafe::ownership::{Self, Borrowable, Withdrawable};

    // public struct MoveCall {
    //     function: String,
    //     arguments: vector<vector<u8>>,
    //     type_arguments: vector<String>
    // }

    // public struct SplitCoins {
    //     source: vector<u8>,
    //     amounts: vector<vector<u8>>
    // }

    public fun execute(safe: &mut Safe, executable: Executable): (Borrowable, Withdrawable) {
        let (_kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);

        let borrowable = bcs.peel_vec_address();
        let withdrawable = bcs.peel_vec_address();
        assert!(!bcs.into_remainder_bytes().is_empty(), 1);

        (
            ownership::new_borrowable(addresses_to_ids(borrowable)), 
            ownership::new_withdrawable(addresses_to_ids(withdrawable))
        )
    }
}