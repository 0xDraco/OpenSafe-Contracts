// module opensafe::storage {
//     use sui::math;
//     use sui::table_vec::{Self, TableVec};

//     public struct Storage has key {
//         id: UID,
//         safe: ID,
//         /// The packages that are added to the safe.
//         packages: TableVec<ID>,
//         /// The IDs of the transactions that are associated with the safe.
//         transactions: TableVec<ID>,
//         // The validators that are added to the safe.
//         // validators: TableVec<Validator>,

//         // More fields can be added here...
//     }

//     const EInvalidOffset: u64 = 0;

//     public(package) fun new(safe: ID, ctx: &mut TxContext): Storage {
//         Storage {
//             id: object::new(ctx),
//             safe,
//             packages: table_vec::empty(ctx),
//             transactions: table_vec::empty(ctx),
//         }
//     }

//     #[allow(lint(share_owned))]
//     public fun share(self: Storage) {
//         transfer::share_object(self)
//     }

//     public(package) fun add_package(self: &mut Storage, package: ID) {
//         self.packages.push_back(package);
//     }

//     public(package) fun add_transaction(self: &mut Storage, transaction_id: ID) {
//         self.transactions.push_back(transaction_id);
//     }

//     public fun id(self: &Storage): ID {
//         self.id.to_inner()
//     }

//     public fun total_transactions(self: &Storage): u64 {
//         self.transactions.length()
//     }

//     public fun total_packages(self: &Storage): u64 {
//         self.packages.length()
//     }

//     public fun get_transactions(self: &Storage, offset_opt: Option<u64>, limit_opt: Option<u64>): vector<ID> {
//         let transactions_count = self.transactions.length();

//         let offset = offset_opt.destroy_with_default(0);
//         let limit = limit_opt.destroy_with_default(transactions_count);
//         assert!(offset <= transactions_count, EInvalidOffset);

//         let end = math::min(offset + limit, transactions_count);
//         let (mut i, mut transactions) = (offset, vector::empty());

//         while (i < end) {
//             transactions.push_back(self.transactions[i]);
//             i = i + 1;
//         };

//         transactions
//     }

//     public fun get_packages(self: &Storage, offset_opt: Option<u64>, limit_opt: Option<u64>): vector<ID> {
//         let packages_count = self.packages.length();

//         let offset = offset_opt.destroy_with_default(0);
//         let limit = limit_opt.destroy_with_default(packages_count);
//         assert!(offset <= packages_count, EInvalidOffset);

//         let end = math::min(offset + limit, packages_count);
//         let (mut i, mut packages) = (offset, vector::empty());

//         while (i < end) {
//             packages.push_back(self.packages[i]);
//             i = i + 1;
//         };

//         packages
//     }
// }