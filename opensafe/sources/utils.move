module opensafe::utils {
    use std::type_name;

    public fun type_bytes<T>(): vector<u8> {
        type_name::get<T>().into_string().into_bytes()
    }

    public fun id_bytes<T: key>(object: &T): vector<u8> {
        object::borrow_id(object).to_bytes()
    }
}