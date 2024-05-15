// module opensafe::witness {
//     use sui::clock::Clock;

//     use opensafe::safe::{Safe, OwnerCap};
//     use opensafe::transaction::Transaction;

//     public struct ExecutionWitness has drop {
//         safe: ID,
//         transaction: ID
//     }

//     public struct SafeWitness has drop {
//         safe: ID
//     }

//     const EInvalidOwnerCap: u64 = 0;
//     const EInvalidTransactionStatus: u64 = 1;
//     const ETransactionIsInvalidated: u64 = 2;
//     const ETransactionDelayNotExpired: u64 = 3;

//     public fun simple_(safe: &Safe, owner_cap: &OwnerCap, ctx: &TxContext): SimpleWitness {
//         assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);

//         SimpleWitness { safe: safe.id() }
//     }

//     public fun new(safe: &Safe, transaction: &Transaction, owner_cap: &OwnerCap, clock: &Clock, ctx: &TxContext): TransactionWitness {
//         assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);

//         assert!(transaction.is_approved(), EInvalidTransactionStatus);
//         assert!(!transaction.is_invalidated(safe), ETransactionIsInvalidated);
//         assert!(transaction.is_execution_delay_expired(safe, clock), ETransactionDelayNotExpired);
//         TransactionWitness { safe: safe.id(), transaction: transaction.id() }
//     }

//     public fun safe(witness: &SafeWitness): ID {
//         witness.safe
//     }
// }