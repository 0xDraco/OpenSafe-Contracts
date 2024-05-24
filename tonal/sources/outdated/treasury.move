// module opensafe::treasury {
//     use sui::coin::Coin;
//     use sui::dynamic_object_field as ofield;

//     use opensafe::utils;

//     public struct Treasury has key {
//         id: UID,
//         safe: ID,
//     } 

//     public struct Key has copy, store, drop {
//         key: vector<u8>
//     }

//     const EObjectAlreadyDeposited: u64 = 0;
//     const EObjectNotFound: u64 = 1;
//     const EInsufficientCoinBalance: u64 = 2;

//     public(package) fun new(safe: ID, ctx: &mut TxContext): Treasury {
//         Treasury { id: object::new(ctx), safe }
//     }

//     #[allow(lint(share_owned))]
//     public fun share(self: Treasury) {
//         transfer::share_object(self)
//     }

//     public fun deposit_coin<T>(self: &mut Treasury, deposit: Coin<T>) {
//         let key = Key { key: utils::type_bytes<T>() };

//         if (ofield::exists_with_type<Key, Coin<T>>(&self.id, key)) {
//             let coin = ofield::borrow_mut<Key, Coin<T>>(&mut self.id, key);
//             coin.join(deposit)
//         } else {
//             ofield::add(&mut self.id, key, deposit)
//         }
//     }

//     public fun deposit_object<T: key + store>(self: &mut Treasury, object: T) {
//         let key = Key { key: utils::id_bytes(&object) };

//         assert!(!ofield::exists_with_type<Key, T>(&self.id, key), EObjectAlreadyDeposited);
//         ofield::add(&mut self.id, key, object)
//     }

//     public(package) fun withdraw_coin<T>(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<T> {
//         let key = Key { key: utils::type_bytes<T>() };

//         assert!(ofield::exists_with_type<Key, Coin<T>>(&self.id, key), EObjectNotFound);
//         let coin = ofield::borrow_mut<Key, Coin<T>>(&mut self.id, key);

//         assert!(coin.value() >= amount, EInsufficientCoinBalance);
//         coin.split(amount, ctx)
//     }

//     public(package) fun withdraw_object<T: key + store>(self: &mut Treasury, id: ID): T {
//         let key = Key { key: id.to_bytes() };
//         assert!(ofield::exists_with_type<Key, T>(&self.id, key), EObjectNotFound);

//         ofield::remove(&mut self.id, key)
//     }

//     public fun id(self: &Treasury): ID {
//         object::id(self)
//     }

//     public fun safe(self: &Treasury): ID {
//         self.safe
//     }
// }
