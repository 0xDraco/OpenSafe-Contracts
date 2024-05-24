module opensafe::package_management {
    use std::string::String;

    use sui::bcs;
    use sui::clock::Clock;
    use sui::transfer::Receiving;
    use sui::dynamic_field as field;
    use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

    use opensafe::safe::Safe;
    use opensafe::executor::Executable;
    use opensafe::transaction::{Self, Transaction};

    public struct Package has key {
        id: UID,
        name: String,
        last_upgrade_ms: u64,
        upgrades: vector<ID>,
        upgrade_cap: UpgradeCap
    }

    public struct UpgradePayload has store, drop {
        digest: vector<u8>,
        dependencies: vector<ID>,
        modules: vector<vector<u8>>
    }

    public struct PayloadKey has copy, store, drop {}

    const EUpgradePackageMismatch: u64 = 1;
    const EUpgradeCurrentlyInProgress: u64 = 2;

    public fun create(safe: &mut Safe, name: String, upgrade_cap: UpgradeCap, ctx: &mut TxContext) {
        let package = Package {
            id: object::new(ctx),
            name,
            last_upgrade_ms: 0,
            upgrades: vector::empty(),
            upgrade_cap
        };

        transfer::transfer(package, safe.to_address())
    }

    public fun create_with_receiving(safe: &mut Safe, name: String, receiving: Receiving<UpgradeCap>, ctx: &mut TxContext) {
        let upgrade_cap = transfer::public_receive(safe.uid_mut_inner(), receiving);
        create(safe, name, upgrade_cap, ctx)
    }

    public fun upgrade(
        safe: &mut Safe,
        digest: vector<u8>,
        dependencies: vector<ID>,
        modules: vector<vector<u8>>,
        receiving: Receiving<Package>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Transaction {
        let package = transfer::receive(safe.uid_mut_inner(), receiving);
        assert!(!field::exists_(safe.uid_inner(), PayloadKey {}), EUpgradeCurrentlyInProgress);

        let data = vector::singleton(bcs::to_bytes(&(package.id.to_inner())));
        let transaction = transaction::create(safe, 0, data, clock, ctx);
        let payload = UpgradePayload { digest, modules, dependencies };

        field::add(safe.uid_mut_inner(), PayloadKey {}, payload);
        transfer::transfer(package, safe.to_address());
        transaction
    }

    public fun execute(safe: &mut Safe, executable: Executable, receiving: Receiving<Package>): UpgradeTicket {
        let (_kind, data) = executable.destroy(safe);
        let mut package = transfer::receive(safe.uid_mut_inner(), receiving);
        let payload = field::remove<PayloadKey, UpgradePayload>(&mut package.id, PayloadKey {});

        let package_id = bcs::new(data).peel_address().to_id();
        assert!(package_id == package.id.to_inner(), EUpgradePackageMismatch);
       
        let policy = package.upgrade_cap.policy();
        let ticket = package.upgrade_cap.authorize_upgrade(policy, payload.digest);

        transfer::transfer(package, safe.to_address());
        ticket
    }

    public fun commit(safe: &mut Safe, receipt: UpgradeReceipt, receiving: Receiving<Package>) {
        let mut package = transfer::receive(safe.uid_mut_inner(), receiving);
        package.upgrade_cap.commit_upgrade(receipt);
        transfer::transfer(package, safe.to_address());
    }
}