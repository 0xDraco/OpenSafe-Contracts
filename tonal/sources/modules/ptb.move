module tonal::ptb {
    use sui::bcs;

    use tonal::safe::Safe;
    use tonal::execution::Executable;
    use tonal::utils::addresses_to_ids;
    use tonal::ownership::{Self, Borrowable, Withdrawable};

    const EPTBTransactionDigestMismatch: u64 = 0;
 
    public fun execute(safe: &mut Safe, digest: vector<u8>, executable: Executable): (Borrowable, Withdrawable) {
        let (_kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);
        
        assert!(bcs.peel_vec_u8() == digest, EPTBTransactionDigestMismatch);

        let borrowable = bcs.peel_vec_address();
        let withdrawable = bcs.peel_vec_address();
        assert!(!bcs.into_remainder_bytes().is_empty(), 1);

        (
            ownership::new_borrowable(addresses_to_ids(borrowable)), 
            ownership::new_withdrawable(addresses_to_ids(withdrawable))
        )
    }
}