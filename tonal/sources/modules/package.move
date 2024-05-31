module tonal::package_management {
    use std::string::String;

    use sui::bcs;
    use sui::transfer::Receiving;
    use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

    use tonal::safe::Safe;
    use tonal::execution::Executable;
    use tonal::transaction::SecureTransaction;

    public struct IndexedPackage has key {
        id: UID,
        name: String,
        last_upgrade_ms: u64,
        upgrades: vector<u64>,
        upgrade_cap: UpgradeCap
    }

    const PACKAGE_UPGRADE_KIND: u64 = 8;

    const EInvalidActionKind: u64 = 0;
    const EUpgradePackageMismatch: u64 = 1;

    public fun create(safe: &mut Safe, name: String, upgrade_cap: UpgradeCap, ctx: &mut TxContext) {
        let package = IndexedPackage {
            id: object::new(ctx),
            name,
            upgrade_cap,
            last_upgrade_ms: 0,
            upgrades: vector::empty(),
        };

        transfer::transfer(package, safe.get_address())
    }

    public fun create_with_receiving(safe: &mut Safe, name: String, receiving: Receiving<UpgradeCap>, ctx: &mut TxContext) {
        let upgrade_cap = transfer::public_receive(safe.uid_mut_inner(), receiving);
        create(safe, name, upgrade_cap, ctx)
    }

    public fun add_upgrade(safe: &mut Safe, secure: &mut SecureTransaction, receiving: Receiving<IndexedPackage>) {
        let mut package = transfer::receive(safe.uid_mut_inner(), receiving);
        package.upgrades.push_back(secure.inner().index());
        transfer::transfer(package, safe.get_address())
    }

    public fun execute(safe: &mut Safe, executable: Executable, receiving: Receiving<IndexedPackage>): (UpgradeTicket, IndexedPackage) {
        let (kind, data) = executable.destroy(safe);
        assert!(kind == PACKAGE_UPGRADE_KIND, EInvalidActionKind);

        let mut bcs = bcs::new(data);
        let mut package = transfer::receive(safe.uid_mut_inner(), receiving);

        let digest = bcs.peel_vec_u8();
        let package_id = bcs.peel_address().to_id();
        assert!(package_id == package.id.to_inner(), EUpgradePackageMismatch);
       
        let policy = package.upgrade_cap.policy();
        let ticket = package.upgrade_cap.authorize_upgrade(policy, digest);
        (ticket, package)
    }

    public fun commit(safe: &mut Safe, receipt: UpgradeReceipt, mut package: IndexedPackage) {
        package.upgrade_cap.commit_upgrade(receipt);
        transfer::transfer(package, safe.get_address());
    }
}