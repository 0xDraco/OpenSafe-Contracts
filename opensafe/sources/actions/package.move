module opensafe::package_management {
    use std::string::String;

    use sui::bcs;
    use sui::clock::Clock;
    use sui::transfer::Receiving;
    use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

    use opensafe::storage::Storage;
    use opensafe::executor::Executable;
    use opensafe::safe::{Safe, OwnerCap};
    use opensafe::transaction::{Self, Transaction};

    public struct Package has key {
        id: UID,
        name: String,
        last_upgrade_ms: u64,
        upgrade_cap: UpgradeCap,
    }

    public struct UpgradePayload has store, copy {
        digest: vector<u8>,
        dependencies: vector<ID>,
        modules: vector<vector<u8>>
    }

    public struct Upgrade has key {
        id: UID,
        package: ID,
        version: u64,
        transaction: ID,
        payload: Option<UpgradePayload>,
    }

    const EUpgradeIdMismatch: u64 = 0;
    const EUpgradePackageMismatch: u64 = 1;
    const EUpgradePayloadIsRequired: u64 = 2;


    public fun create(name: String, upgrade_cap: UpgradeCap, ctx: &mut TxContext) {
        let package = Package {
            id: object::new(ctx),
            name,
            last_upgrade_ms: 0,
            upgrade_cap,
        };

        transfer::transfer(package, @0x0)
    }

    public fun upgrade(
        safe: &mut Safe,
        owner: &mut OwnerCap,
        storage: &mut Storage,
        digest: vector<u8>,
        dependencies: vector<ID>,
        modules: vector<vector<u8>>,
        receiving: Receiving<Package>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Transaction, Upgrade) {
        let upgrade_id = object::new(ctx);

        let package = transfer::receive(safe.uid_mut_inner(), receiving);
        let payload = UpgradePayload { digest, dependencies, modules };

        let data = vector::singleton(bcs::to_bytes(&upgrade_id.to_inner()));
        let transaction = transaction::create(safe, owner, storage, 0, data, clock, ctx);

        let upgrade = Upgrade {
            id: upgrade_id,
            transaction: transaction.id(),
            package: package.id.to_inner(),
            payload: option::some(payload),
            version: package.upgrade_cap.version(),
        };

        transfer::transfer(package, @0x0);
        (transaction, upgrade)
    }

    public fun execute(safe: &mut Safe, upgrade: &mut Upgrade, executable: Executable, receiving: Receiving<Package>): UpgradeTicket {
        let (_kind, data) = executable.destroy(safe);
        let mut package = transfer::receive(safe.uid_mut_inner(), receiving);

        let upgrade_id = bcs::new(data).peel_address().to_id();
        assert!(upgrade_id == upgrade.id.to_inner(), EUpgradeIdMismatch);
        assert!(upgrade.package == package.id.to_inner(), EUpgradePackageMismatch);
        assert!(upgrade.payload.is_some(), EUpgradePayloadIsRequired);
        let UpgradePayload {dependencies: _, modules: _, digest} = upgrade.payload.destroy_some();

        let policy = package.upgrade_cap.policy();
        let ticket = package.upgrade_cap.authorize_upgrade(policy, digest);

        transfer::transfer(package, @0x0);

        ticket
    }

    public fun commit(safe: &mut Safe, receipt: UpgradeReceipt, receiving: Receiving<Package>) {
        let mut package = transfer::receive(safe.uid_mut_inner(), receiving);
        package.upgrade_cap.commit_upgrade(receipt);
        transfer::transfer(package, @0x0);
    }
}