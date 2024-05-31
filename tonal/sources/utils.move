module tonal::utils {
    use std::type_name;
    use std::string::{String, utf8};

    use sui::bcs::{Self, BCS};
    use sui::vec_map::{Self, VecMap};

    public fun type_bytes<T>(): vector<u8> {
        type_name::get<T>().into_string().into_bytes()
    }

    public fun id_bytes<T: key>(object: &T): vector<u8> {
        object::borrow_id(object).to_bytes()
    }

    public fun json_to_vec_map(data: vector<u8>): VecMap<String, String> {
        let mut bcs = bcs::new(data);
        let values = bcs.peel_vec_vec_u8();
        assert!(bcs.into_remainder_bytes().is_empty(), 0);

        let mut map = vec_map::empty();

        let mut i = 0;
        while(i < values.length()) {
            let value = values[i];
            let mut bcs = bcs::new(value);

            let k = utf8(bcs.peel_vec_u8());
            let v = utf8(bcs.peel_vec_u8());

            assert!(bcs.into_remainder_bytes().is_empty(), 1);

            map.insert(k, v);
            i = i + 1;
        };

        map
   }

    public fun peel_vec_id(bcs: &mut BCS): vector<ID> {
        let (len, mut i, mut res) = (bcs.peel_vec_length(), 0, vector[]);
        while (i < len) {
            res.push_back(bcs.peel_address().to_id());
            i = i + 1;
        };
        res
    }
}