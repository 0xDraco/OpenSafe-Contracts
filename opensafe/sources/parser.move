module tonal::parser {
    use sui::bcs;

    const EDataParseFailure: u64 = 1;

    public fun parse_data(data: vector<u8>): (u64, vector<u8>) {
        let mut bcs = bcs::new(data);
        let kind = bcs.peel_u64();

        (kind, bcs.into_remainder_bytes())
    }

    public fun parse_address(data: vector<u8>): address {
        let mut bcs = bcs::new(data);
        let value = bcs.peel_address();
        assert!(bcs.into_remainder_bytes().is_empty(), EDataParseFailure);

        value
    }

    public fun parse_u64(data: vector<u8>): u64 {
        let mut bcs = bcs::new(data);
        let value = bcs.peel_u64();
        assert!(bcs.into_remainder_bytes().is_empty(), EDataParseFailure);

        value
    }

    public fun parse_coin_transfer_data(data: vector<u8>): (u64, address, vector<u8>) {
        let mut bcs = bcs::new(data);

        let amount = bcs.peel_u64();
        let recipient = bcs.peel_address();
        let coin_type = bcs.peel_vec_u8();
        assert!(bcs.into_remainder_bytes().is_empty(), EDataParseFailure);

        (amount, recipient, coin_type)
    }

    public fun parse_object_transfer_data(data: vector<u8>): (address, address) {
        let mut bcs = bcs::new(data);

        let id = bcs.peel_address(); // object ID address
        let recipient = bcs.peel_address();
        assert!(bcs.into_remainder_bytes().is_empty(), EDataParseFailure);

        (id, recipient)
    }

    public fun parse_programmable_transaction_data(data: vector<u8>): (vector<vector<u8>>, vector<vector<u8>>) {
        let mut bcs = bcs::new(data);

        let inputs = bcs.peel_vec_vec_u8(); 
        let operations = bcs.peel_vec_vec_u8();
        assert!(bcs.into_remainder_bytes().is_empty(), EDataParseFailure);

        (inputs, operations)
    }
}