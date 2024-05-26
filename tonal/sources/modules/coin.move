module tonal::coin {
    use sui::bcs;
    use sui::coin::Coin;
    use sui::transfer::Receiving;

    use tonal::safe::Safe;
    use tonal::execution::Executable;
    use tonal::ownership::{Self, WrappedObject};

    const COIN_TRANSFER_KIND: u64 = 0;

    const EInvalidActionKind: u64 = 0;
    const EIvalidCoinValue: u64 = 1;

    public fun execute<T>(safe: &mut Safe, executable: Executable, receiving: Receiving<Coin<T>>) {
        let coin = transfer::public_receive(safe.uid_mut_inner(), receiving);
        execute_(safe, executable, coin)
    }

    public fun execute_<T>(safe: &Safe, executable: Executable, coin: Coin<T>) {
        let (kind, data) = executable.destroy(safe);
        // assert!(kind == COIN_TRANSFER_KIND, EInvalidActionKind);

        let mut bcs = bcs::new(data);
        let coin_type = bcs.peel_vec_u8();
        let recipient = bcs.peel_address();

        // assert!(utils::type_bytes<T>() == coin_type, 0);
        assert!(coin.value() == bcs.peel_u64(), EIvalidCoinValue);

        transfer::public_transfer(coin, recipient);
        assert!(bcs.into_remainder_bytes().is_empty(), 1);
    }

    public fun batch_execute_<T>(safe: &Safe, executable: Executable, coins: &mut vector<WrappedObject<Coin<T>>>) {
        let coin = coins.pop_back().unwrap();
        execute_(safe, executable, coin);
    }

    public fun destroy_empty_wrapped<T>(v: vector<WrappedObject<Coin<T>>>) {
        v.destroy_empty()
    }

    public fun split_and_return<T>(safe: &mut Safe, receiving: Receiving<Coin<T>>, amounts: vector<u64>, ctx: &mut TxContext): vector<WrappedObject<Coin<T>>> {
        let coin = transfer::public_receive(safe.uid_mut_inner(), receiving);
        split(safe, coin, amounts, ctx)
    }

    public fun split_and_return_wrapped<T>(safe: &mut Safe, wrapped: WrappedObject<Coin<T>>, amounts: vector<u64>, ctx: &mut TxContext): vector<WrappedObject<Coin<T>>> {
        let coin = wrapped.unwrap();
        split(safe, coin, amounts, ctx)
    }

    public fun split<T>(safe: &mut Safe, mut coin: Coin<T>, amounts: vector<u64>, ctx: &mut TxContext): vector<WrappedObject<Coin<T>>> {
        safe.assert_sender_owner(ctx);
        let (mut i, mut splits) = (0, vector::empty());

        while(i < amounts.length()) {
            let split = coin.split(amounts[i], ctx);
            splits.push_back(ownership::wrap(split));
            i = i + 1;
        };

        if(coin.value() == 0){
            coin.destroy_zero();
        } else {
            transfer::public_transfer(coin, safe.get_address());
        };

       splits
    }

    // public fun merge<T>(safe: &mut Safe, destination: Receiving<Coin<T>>, sources: vector<Receiving<Coin<T>>>, ctx: &mut TxContext) {
    //     transfer::public_transfer(merge_and_return(safe, destination, sources, ctx), safe.get_address())
    // }

    public fun merge_and_return<T>(safe: &mut Safe, destination: Receiving<Coin<T>>, mut sources: vector<Receiving<Coin<T>>>, ctx: &mut TxContext): WrappedObject<Coin<T>> {
        safe.assert_sender_owner(ctx);
        let mut coin = transfer::public_receive(safe.uid_mut_inner(), destination);

        while(!sources.is_empty()) {
            coin.join(transfer::public_receive(safe.uid_mut_inner(), sources.pop_back()));
        };

        sources.destroy_empty();
        ownership::wrap(coin)
    }
}