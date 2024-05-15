module package::manager {
    use sui::clock::Clock;
    use sui::package::{UpgradeTicket, UpgradeReceipt};

    use opensafe::safe::Safe;
    use opensafe::witness::SafeWitness;

    use package::package::{Package, Upgrade, UpgradePayload};


    public struct PackageManager has key {
        id: UID,
        safe: ID,
        packages: vector<Package>
    }

    const EPackageAlreadyAdded: u64 = 0;
    const EPackageNotFound: u64 = 1;
    const ESafeWitnessMismatch: u64 = 2;

    public fun new(witness: &SafeWitness, safe: &Safe, ctx: &mut TxContext): PackageManager {
        assert!(witness.safe() == safe.id(), ESafeWitnessMismatch);

        PackageManager {
            safe: safe.id(),
            id: object::new(ctx),
            packages: vector::empty()
        }
    }

    public fun add_package(self: &mut PackageManager, witness: &SafeWitness, package: Package) {
        assert!(self.safe() == witness.safe(), ESafeWitnessMismatch);
        assert!(find_package_index(self, package.upgrade_cap_id()).is_none(), EPackageAlreadyAdded);

        self.packages.push_back(package)
    }

    public fun remove_package(self: &mut PackageManager, witness: &SafeWitness, upgrade_cap: ID): Package {
        assert!(self.safe() == witness.safe(), ESafeWitnessMismatch);

        let index = find_package_index(self, upgrade_cap);
        assert!(!index.is_none(), EPackageNotFound);

        self.packages.remove(index.destroy_some())
    }

    public fun new_upgrade(
        self: &mut PackageManager,
        witness: &SafeWitness,
        upgrade_cap: ID,
        digest: vector<u8>,
        modules: vector<u8>,
        dependencies: vector<ID>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Upgrade, UpgradePayload) {
        assert!(self.safe() == witness.safe(), ESafeWitnessMismatch);

        let index = find_package_index(self, upgrade_cap);
        assert!(!index.is_none(), EPackageNotFound);

        let package = &mut self.packages[index.destroy_some()];
        package.new_upgrade(digest, modules, dependencies, clock, ctx)
    }

    public fun authorize_upgrade(self: &mut PackageManager, witness: &SafeWitness, upgrade: &mut Upgrade, payload: &UpgradePayload): UpgradeTicket {
        assert!(self.safe() == witness.safe(), ESafeWitnessMismatch);

        let index = find_package_index(self, upgrade.upgrade_cap());
        assert!(!index.is_none(), EPackageNotFound);

        let package = &mut self.packages[index.destroy_some()];
        package.authorize_upgrade(upgrade, payload)
    }

    public fun commit_upgrade(self: &mut PackageManager, witness: &SafeWitness,  upgrade: &mut Upgrade, payload: UpgradePayload, receipt: UpgradeReceipt, clock: &Clock) {
        assert!(self.safe() == witness.safe(), ESafeWitnessMismatch);
        let index = find_package_index(self, upgrade.upgrade_cap());
        assert!(!index.is_none(), EPackageNotFound);

        let package = &mut self.packages[index.destroy_some()];
        package.commit_upgrade(upgrade, payload, receipt, clock)
    }

    public fun find_package_index(self: &PackageManager, id: ID): Option<u64> {
        let (mut i, packages_count) = (0, self.packages.length());
        while (i < packages_count) {
            let package = &self.packages[i];

            if(package.upgrade_cap_id() == id) {
                return option::some(i)
            };

            i = i + 1;
        };

        option::none()
    }

    public fun safe(self: &PackageManager): ID {
        self.safe
    }
}