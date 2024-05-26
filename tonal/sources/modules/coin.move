module tonal::coin {
    use sui::coin::Coin;
    use sui::transfer::Receiving;

    use tonal::safe::Safe;

    public fun split<T>(safe: &mut Safe, receiving: Receiving<Coin<T>>, amounts: vector<u64>, ctx: &mut TxContext): vector<ID> {
        let coin = transfer::public_receive(safe.uid_mut_inner(), receiving);
        split_from_coin(safe, coin, amounts, ctx)
    }

    public fun merge<T>(safe: &mut Safe, destination: Receiving<Coin<T>>, sources: vector<Receiving<Coin<T>>>, ctx: &TxContext) {
        let coin = merge_and_return_coin(safe, destination, sources, ctx);
        transfer::public_transfer(coin, safe.get_address());
    }

    public fun split_from_coin<T>(safe: &mut Safe, mut coin: Coin<T>, amounts: vector<u64>, ctx: &mut TxContext): vector<ID> {
        safe.assert_sender_owner(ctx);
        let (mut i, mut ids) = (0, vector::empty());

        while(i < amounts.length()) {
            let split = coin.split(amounts[i], ctx);
            ids.push_back(object::id(&split));
            transfer::public_transfer(split, safe.get_address());
            i = i + 1;
        };

        if(coin.value() == 0){
            coin.destroy_zero();
        } else {
            transfer::public_transfer(coin, safe.get_address());
        };

       ids
    }

    public(package) fun merge_and_return_coin<T>(safe: &mut Safe, destination: Receiving<Coin<T>>, mut sources: vector<Receiving<Coin<T>>>, ctx: &TxContext): Coin<T> {
        safe.assert_sender_owner(ctx);
        let mut coin = transfer::public_receive(safe.uid_mut_inner(), destination);

        while(!sources.is_empty()) {
            coin.join(transfer::public_receive(safe.uid_mut_inner(), sources.pop_back()));
        };

        sources.destroy_empty();
        coin
    }
}