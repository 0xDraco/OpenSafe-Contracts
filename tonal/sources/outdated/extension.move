// module opensafe::extension {
//     use sui::bag::{Self, Bag};
//     use sui::dynamic_field as field;

//     use opensafe::safe::Safe;

//     public struct Extension has store {
//         storage: Bag,
//         is_enabled: bool,
//         allow_disable: bool
//     }

//     public struct Key<phantom T> has store, copy, drop {}

//     const EExtensionAlreadyInstalled: u64 = 0;

//     public(package) fun install<Ext: drop>(_ext: Ext, safe: &mut Safe, ctx: &mut TxContext) {
//         assert!(!is_installed<Ext>(safe), EExtensionAlreadyInstalled);

//         let uid = safe.uid_mut_inner();
//         let ext = Extension { storage: bag::new(ctx), is_enabled: false, allow_disable: true};
//         field::add<Key<Ext>, Extension>(uid, Key {}, ext);
//     }

//     public(package) fun storage<Ext: drop>(safe: &Safe): &Bag {
//         &field::borrow<Key<Ext>, Extension>(safe.uid_inner(), Key {}).storage
//     }

//     public(package) fun storage_mut<Ext: drop>(_ext: Ext, safe: &mut Safe): &mut Bag {
//         &mut field::borrow_mut<Key<Ext>, Extension>(safe.uid_mut_inner(), Key {}).storage
//     }

//     public fun is_installed<Ext: drop>(safe: &Safe): bool {
//         let uid = safe.uid_inner();
//         field::exists_with_type<Key<Ext>, Extension>(uid, Key {})
//     }

//     public fun is_enabled<Ext: drop>(safe: &Safe): bool {
//         field::borrow<Key<Ext>, Extension>(safe.uid_inner(), Key {}).is_enabled
//     }

//     public fun is_disable_allowed<Ext: drop>(safe: &Safe): bool {
//         field::borrow<Key<Ext>, Extension>(safe.uid_inner(), Key {}).allow_disable
//     }
// }