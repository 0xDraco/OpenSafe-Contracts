module opensafe::package {
    use std::string::String;

    use sui::bcs;
    use sui::clock::Clock;
    use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

    use opensafe::safe::{Safe, OwnerCap};
    use opensafe::extension;

    public struct Package has store {
        /// The ID of the current version of the package
        current: ID,
        /// The name of the package (optional)
        name: Option<String>,
        /// The timestamp (ms) when the package was last upgraded
        last_upgrade_ms: u64,
        /// The IDs of the upgrades associated with the package
        upgrades: vector<ID>,
        /// The upgrade cap of the package
        upgrade_cap: UpgradeCap,
    }

    public struct UpgradePayload has key {
        id: UID,
        /// The digest of the modules and dependencies, used for verification and integrity checks
        digest: vector<u8>,
        /// The serialized bytecode of the package's modules
        modules: vector<u8>,
        /// The IDs of the dependencies that are used in the package
        dependencies: vector<ID>
    }


    public struct Upgrade has key {
        id: UID,
        /// The ID of the package to be upgraded
        package: ID,
        /// The version of the package to be upgraded
        // version: u64,
        /// The ID of the package's `UpgradeCap`
        upgrade_cap: ID,
        /// The ID transaction that is associated with this upgrade
        // transaction: ID,
        /// The ID of the object where the package payload is stored
        /// This object will be deleted after the upgrade, as the payload is no longer needed
        payload: Option<ID>,
        /// The time (ms) when this upgrade was creaated
        created_at_ms: u64,
        /// The time (ms) when the upgrade was executed
        executed_at_ms: Option<u64>
    }


    public struct Witness has drop {}

    const PACKAGES_KEY: vector<u8> = b"packages";

    const EInvalidOwnerCap: u64 = 0;
    const EPackageAlreadyAdded: u64 = 1;
    const EPackageNotFound: u64 = 2;
    const ESafeNotInstalled: u64 = 3;
    const EUpgradePayloadIsRequired: u64 = 4;
    const EPackagePayloadMismatch: u64 = 5;
    const EUpgradeReceiptMismatch: u64 = 6;
    const EPackageReceiptValueError: u64 = 7;

    public fun add(safe: &mut Safe, owner_cap: &OwnerCap, name: Option<String>, upgrade_cap: UpgradeCap, ctx: &mut TxContext) {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        if(!extension::is_installed<Witness>(safe)) {
            install(safe, owner_cap, ctx);
        };

       
        add_package(safe, name, upgrade_cap);
    }

    public fun remove(safe: &mut Safe, owner_cap: &OwnerCap, upgrade_cap: ID, ctx: &TxContext): UpgradeCap {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        assert!(extension::is_installed<Witness>(safe), ESafeNotInstalled);

        remove_package(safe, upgrade_cap)
    }

    public fun install(safe: &mut Safe, owner_cap: &OwnerCap, ctx: &mut TxContext) {
        assert!(safe.is_valid_owner_cap(owner_cap, ctx), EInvalidOwnerCap);
        extension::install(Witness {}, safe, ctx);

        let storage = extension::storage_mut<Witness>(Witness {}, safe);
        storage.add(PACKAGES_KEY, vector::empty<Package>());
    }

    public(package) fun new_upgrade(
        safe: &mut Safe,
        upgrade_cap: ID,
        digest: vector<u8>,
        modules: vector<u8>,
        dependencies: vector<ID>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Upgrade, UpgradePayload) {
        let package = package_mut(safe, upgrade_cap);
        package.new_upgrade_internal(digest, modules, dependencies, clock, ctx)
    }

    public(package) fun authorize_upgrade(safe: &mut Safe, upgrade: &Upgrade, payload: &UpgradePayload): UpgradeTicket {       
        let package = package_mut(safe, upgrade.upgrade_cap);
        package.authorize_upgrade_internal(upgrade, payload)
    }

    public fun commit_upgrade(
        safe: &mut Safe,
        upgrade: &mut Upgrade,
        payload: UpgradePayload,
        receipt: UpgradeReceipt,
        clock: &Clock
    ) {
        let package = package_mut(safe, upgrade.upgrade_cap);
        package.commit_upgrade_internal(upgrade, payload, receipt, clock)
    }

    // ===== Public Functions =====

    public fun packages(safe: &Safe): &vector<Package> {
        assert!(extension::is_installed<Witness>(safe), ESafeNotInstalled);
        let storage = extension::storage<Witness>(safe);
        &storage[PACKAGES_KEY]
    }

    public fun package(safe: &Safe, upgrade_cap: ID): &Package {
        let storage = extension::storage<Witness>(safe);
        let packages: &vector<Package> = &storage[PACKAGES_KEY];

        let mut i = 0;
        while (i < packages.length()) {
            let package = &packages[i];
            if (upgrade_cap_id(&package.upgrade_cap) == upgrade_cap) {
                return package
            };

            i = i + 1;
        };

        abort EPackageNotFound
    }

    public fun package_index(safe: &Safe, upgrade_cap: ID): Option<u64> {
        let storage = extension::storage<Witness>(safe);
        let packages: &vector<Package> = &storage[PACKAGES_KEY];

        let mut i = 0;
        while (i < packages.length()) {
            let package = &packages[i];
            if (upgrade_cap_id(&package.upgrade_cap) == upgrade_cap) {
                return option::some(i)
            };

            i = i + 1;
        };

        option::none()
    }

    fun add_package(safe: &mut Safe, name: Option<String>, upgrade_cap: UpgradeCap) {
        let upgrade_cap_id = upgrade_cap_id(&upgrade_cap);
        assert!(package_index(safe, upgrade_cap_id).is_none(), EPackageAlreadyAdded);

        let current =  upgrade_cap.package();
        let package = Package {
            name,
            current,
            upgrade_cap,
            last_upgrade_ms: 0,
            upgrades: vector::empty(),
        };

        let storage = extension::storage_mut<Witness>(Witness {}, safe);
        let packages: &mut vector<Package> = &mut storage[PACKAGES_KEY];
        packages.push_back(package);
    }

    fun remove_package(safe: &mut Safe, upgrade_cap: ID): UpgradeCap {
        let index = package_index(safe, upgrade_cap);
        assert!(index.is_some(), EPackageNotFound);

        let storage = extension::storage_mut<Witness>(Witness {}, safe);
        let packages: &mut vector<Package> = &mut storage[PACKAGES_KEY];
        let Package { 
            name: _,
            current: _,
            upgrade_cap,
            upgrades: _,
            last_upgrade_ms: _,
        } = packages.remove(index.destroy_some());

        upgrade_cap
    }

    fun new_upgrade_internal(
        package: &mut Package,
        digest: vector<u8>,
        modules: vector<u8>,
        dependencies: vector<ID>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Upgrade, UpgradePayload) {
        let payload = UpgradePayload { id: object::new(ctx), digest, modules, dependencies };

        let upgrade = Upgrade {
            id: object::new(ctx),
            package: package.current,
            upgrade_cap: upgrade_cap_id(&package.upgrade_cap),
            payload: option::some(payload.id.to_inner()),
            created_at_ms: clock.timestamp_ms(),
            executed_at_ms: option::none()
        };

        package.upgrades.push_back(upgrade.id.to_inner());
        (upgrade, payload)
    }

    fun authorize_upgrade_internal(
        self: &mut Package,
        upgrade: &Upgrade,
        payload: &UpgradePayload
    ): UpgradeTicket {
        assert!(upgrade.payload.is_some(),  EUpgradePayloadIsRequired);
        assert!(upgrade.payload.borrow() == payload.id.as_inner(),  EPackagePayloadMismatch);
        // assert!(upgrade_cap.version() == upgrade.version, EPackageVersionError);
        assert!(upgrade_cap_id(&self.upgrade_cap) == upgrade.upgrade_cap,  EPackagePayloadMismatch);

        let policy = self.upgrade_cap.policy();
        self.upgrade_cap.authorize_upgrade(policy, payload.digest)
    }

    fun package_mut(safe: &mut Safe, upgrade_cap: ID): &mut Package {
        let index = package_index(safe, upgrade_cap);
        assert!(!index.is_none(), EPackageNotFound);

        let storage = extension::storage_mut<Witness>(Witness {}, safe);
        let packages: &mut vector<Package> = &mut storage[PACKAGES_KEY];
        
        &mut packages[index.destroy_some()]
    }

    fun commit_upgrade_internal(
        self: &mut Package,
        upgrade: &mut Upgrade,
        payload: UpgradePayload,
        receipt: UpgradeReceipt, 
        clock: &Clock
     ) {
        let UpgradePayload {id,  modules: _, dependencies: _, digest: _} = payload;

        assert!(upgrade_cap_id(&self.upgrade_cap) == receipt.cap(), EUpgradeReceiptMismatch);
        // assert!(self.upgrade_cap.version() == upgrade.version, EPackageVersionError);
        assert!(upgrade_cap_id(&self.upgrade_cap) == upgrade.upgrade_cap,  EPackagePayloadMismatch);
        assert!(self.upgrade_cap.package() != receipt.package(), EPackageReceiptValueError);

        // upgrade.version = upgrade.version + 1;
        upgrade.executed_at_ms.fill(clock.timestamp_ms());

        id.delete();
        self.upgrade_cap.commit_upgrade(receipt);
    }

    public fun upgrade_cap_id(upgrade_cap: &UpgradeCap): ID {
        let bytes = bcs::to_bytes(upgrade_cap);
        bcs::new(bytes).peel_address().to_id()
    }
}