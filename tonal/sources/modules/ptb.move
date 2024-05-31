module tonal::ptb {
    use sui::bcs;

    use tonal::utils;
    use tonal::safe::Safe;
    use tonal::execution::Executable;
    use tonal::ownership::{Self, Borrowable, Removable};

    const EInvalidActionKind: u64 = 0;
    const ETransactionDigestMismatch: u64 = 1;
    const EInvalidTransactionData: u64 = 2;

    const PTB_KIND: u64 = 7;

    public fun execute(safe: &mut Safe, executable: Executable, ctx: &TxContext): (Removable, Borrowable) {
        let (kind, data) = executable.destroy(safe);
        let mut bcs = bcs::new(data);
        
        assert!(kind == PTB_KIND, EInvalidActionKind);

        let expected_digest = bcs.peel_vec_u8();
        assert!(ctx.digest() == &expected_digest, ETransactionDigestMismatch);

        let removable_ids = utils::peel_vec_id(&mut bcs);
        let borrowable_ids = utils::peel_vec_id(&mut bcs);
        assert!(bcs.into_remainder_bytes().is_empty(), EInvalidTransactionData);

        (
            ownership::new_removable(removable_ids),
            ownership::new_borrowable(borrowable_ids), 
        )
    }
}