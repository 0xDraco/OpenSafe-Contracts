module coin_template::coin_template {
    use sui::url;
    use sui::coin::{Self};


    public struct COIN_TEMPLATE has drop {}

    const DECIMALS: u8 = 9;
    const NAME: vector<u8> = b"Name";
    const SYMBOL: vector<u8> = b"COIN";
    const DESCRIPTION: vector<u8> = b"Description";
    const ICON_URL: vector<u8> = b"IconUrl";

    const OWNER_ADDRESS: address = @0x0;

    #[allow(lint(share_owned))]
    fun init(witness: COIN_TEMPLATE, ctx: &mut TxContext) {
        let icon_url = url::new_unsafe_from_bytes(ICON_URL);
        let (treasury, metadata) = coin::create_currency(witness, DECIMALS, SYMBOL, NAME, DESCRIPTION, option::some(icon_url), ctx);

        transfer::public_share_object(metadata);
        transfer::public_transfer(treasury, OWNER_ADDRESS)
    }
}