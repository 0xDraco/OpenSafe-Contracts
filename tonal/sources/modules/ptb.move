module tonal::ptb {
    use sui::bcs;

    use tonal::safe::Safe;
    use tonal::execution::Executable;
    use tonal::utils::addresses_to_ids;
    use tonal::ownership::{Self, Borrowable, Removable};

    const ETransactionTypeMismatch: u64 = 0;
    const ETransactionDigestMismatch: u64 = 1;

    const PTB_TRANSACTION_KIND: u64 = 2;
 
    public fun execute(safe: &mut Safe, digest: vector<u8>, executable: Executable): (Removable, Borrowable) {
        let (kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);
        
        assert!(kind == PTB_TRANSACTION_KIND, ETransactionTypeMismatch);
        assert!(bcs.peel_vec_u8() == digest, ETransactionDigestMismatch);

        let removable = bcs.peel_vec_address();
        let borrowable = bcs.peel_vec_address();
        assert!(!bcs.into_remainder_bytes().is_empty(), 1);

        (
            ownership::new_removable(addresses_to_ids(removable)),
            ownership::new_borrowable(addresses_to_ids(borrowable)), 
        )
    }
}