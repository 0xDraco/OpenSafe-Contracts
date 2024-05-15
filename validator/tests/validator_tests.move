#[test_only]
module validator::validator_tests {
    public struct TestPrivateStruct has key {
        id: UID,
        addr: address
    }

    public fun new(addr: address, ctx: &mut TxContext): TestPrivateStruct {
        TestPrivateStruct { id: object::new(ctx), addr}
    }

    public fun destroy(s: TestPrivateStruct) {
      let TestPrivateStruct { id, addr: _ } = s;
      id.delete();
    }
}

#[test_only]
module validator::out_tests {
    use std::debug;

    use sui::bcs;
    use validator::validator_tests;

    #[test]
    fun test_out() {
        let mut ctx = tx_context::dummy();

        let s = validator_tests::new(@0x1, &mut ctx);
        
        debug::print(&s);

        let mut bcs = bcs::new(bcs::to_bytes(&s));
        debug::print(&bcs);


        debug::print(&bcs.peel_address());
        debug::print(&bcs.peel_address());

        s.destroy();
    }
}

