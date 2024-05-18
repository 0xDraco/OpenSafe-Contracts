module opensafe::storage {
    use sui::table_vec::{Self, TableVec};

    public struct Storage has store {
        /// The IDs of the transactions that are associated with the safe.
        transactions: TableVec<ID>,
        /// The packages that are added to the safe.
        packages: TableVec<ID>,
        // The validators that are added to the safe.
        // validators: TableVec<Validator>,

        // More fields can be added here. dynamic fields? 
    }

    public struct Key has copy, store, drop {}


    public(package) fun new(ctx: &mut TxContext): Storage {
        Storage {
            packages: table_vec::empty(ctx),
            transactions: table_vec::empty(ctx),
        }
    }

    public(package) fun key(): Key {
        Key {}
    }

    public fun add_package(self: &mut Storage, package: ID) {
        self.packages.push_back(package);
    }

    public(package) fun add_transaction(self: &mut Storage, transaction_id: ID) {
        self.transactions.push_back(transaction_id);
    }

    public(package) fun transaction_at(self: &Storage, index: u64): ID {
        self.transactions[index]
    }

    public fun total_transactions(self: &Storage): u64 {
        self.transactions.length()
    }
}