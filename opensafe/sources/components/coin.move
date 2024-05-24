module opensafe::send_coin {
    use sui::bcs;
    use sui::coin::Coin;
    use sui::transfer::Receiving;

    use opensafe::utils;
    use opensafe::safe::Safe;
    use opensafe::executor::Executable;

    const COIN_TRANSFER_KIND: u64 = 0;

    const EInvalidActionKind: u64 = 0;
    const EInsufficientCoinValue: u64 = 1;

    public fun execute<T>(safe: &mut Safe, executable: Executable, receiving: Receiving<Coin<T>>, ctx: &mut TxContext) {
        let (kind, data) = executable.destroy(safe);
        assert!(kind == COIN_TRANSFER_KIND, EInvalidActionKind);

        let mut bcs = bcs::new(data);
        let coin_type = bcs.peel_vec_u8();
        let recipient = bcs.peel_address();
        let amount = bcs.peel_u64();

        let mut coin = transfer::public_receive(safe.uid_mut_inner(), receiving);
        assert!(amount <= coin.value(), EInsufficientCoinValue);
        assert!(utils::type_bytes<T>() == coin_type, 0);

        if(coin.value() == amount) {
            transfer::public_transfer(coin, recipient);
        } else {
            transfer::public_transfer(coin.split(amount, ctx), recipient);
            transfer::public_transfer(coin, safe.get_address());
        };

        assert!(bcs.into_remainder_bytes().is_empty(), 1);
    }

    public fun batch_execute<T>(safe: &mut Safe, executables: &mut vector<Executable>, receiving: Receiving<Coin<T>>, ctx: &mut TxContext) {
        execute(safe, executables.pop_back(), receiving, ctx);
    }
}