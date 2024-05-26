module tonal::transfer {
    use sui::bcs;
    use sui::coin::Coin;
    use sui::transfer::Receiving;

    use tonal::coin;
    use tonal::safe::Safe;
    use tonal::execution::Executable;

    const TRANSFER_OBJECT_KIND: u64 = 1;
    const SHARE_OBJECT_KIND: u64 = 2;
    const FREEZE_OBJECT_KIND: u64 = 3;

    const EObjectIDMismatch: u64 = 0;
    const EInvalidActionKind: u64 = 1;
    const ERecipientsAmountLengthMismatch: u64 = 0;

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

    public fun prepare_coins_transfer<T>(safe: &mut Safe, mut receivings: vector<Receiving<Coin<T>>>, recipients: vector<address>, amounts: vector<u64>, ctx: &mut TxContext): vector<vector<u8>> {
        safe.assert_sender_owner(ctx);
        assert!(recipients.length() == amounts.length(), ERecipientsAmountLengthMismatch);

        let coin_ids;
        let receiving = receivings.pop_back();
        if(!receivings.is_empty()) {
            let coin = coin::merge_and_return_coin(safe, receiving, receivings, ctx);
            coin_ids = coin::split_from_coin(safe, coin, amounts, ctx);
        } else {
            coin_ids = coin::split(safe, receiving, amounts, ctx);
        };

        let (mut i, mut transfers) = (0, vector::empty());
        while(i < coin_ids.length()) {
            let mut bytes = vector::empty();
            bytes.append(bcs::to_bytes(&coin_ids[i]));
            bytes.append(bcs::to_bytes(&recipients[i]));

            transfers.push_back(bytes);
            i = i + 1;
        };

       transfers
    }
}