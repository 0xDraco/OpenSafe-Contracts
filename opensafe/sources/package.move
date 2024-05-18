module opensafe::package {
    use std::string::String;

    use sui::bcs;
    use sui::clock::Clock;
    use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

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
        /// initially the version of the package to be upgraded, incremented after a successful upgrade
        version: u64,
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

    const EInvalidUpgrade: u64 = 1;
    const EUpgradePayloadIsRequired: u64 = 4;
    const EPackagePayloadMismatch: u64 = 5;
    const EUpgradeReceiptMismatch: u64 = 6;
    const EPackageReceiptMismatch: u64 = 7;
    const EUpgradeAlreadyExecuted: u64 = 8;
    const EPackageVersionError: u64 = 9;

    public fun new(name: Option<String>, upgrade_cap: UpgradeCap, ctx: &mut TxContext): Package {
        let current = upgrade_cap.package();

        Package {
            name,
            current,
            upgrade_cap,
            last_upgrade_ms: 0,
            upgrades: vector::empty(),
        }
    }

    public fun new_upgrade(self: &mut Package, digest: vector<u8>, modules: vector<u8>, dependencies: vector<ID>, clock: &Clock, ctx: &mut TxContext): (Upgrade, UpgradePayload) {
       let payload = UpgradePayload { id: object::new(ctx), digest, modules, dependencies };
        let upgrade = Upgrade {
            id: object::new(ctx),
            package: self.current,
            version: self.upgrade_cap.version(),
            upgrade_cap: upgrade_cap_id(&self.upgrade_cap),
            payload: option::some(payload.id.to_inner()),
            created_at_ms: clock.timestamp_ms(),
            executed_at_ms: option::none()
        };

        self.upgrades.push_back(upgrade.id.to_inner());
        (upgrade, payload)
    }

    public fun authorize_upgrade(self: &mut Package, upgrade: &Upgrade, payload: &UpgradePayload): UpgradeTicket {       
        assert!(upgrade.payload.is_some(), EUpgradePayloadIsRequired);
        assert!(upgrade.executed_at_ms.is_none(), EUpgradeAlreadyExecuted);
        assert!(self.upgrades.contains(upgrade.id.as_inner()), EInvalidUpgrade);
        assert!(upgrade.payload.borrow() == payload.id.as_inner(),  EPackagePayloadMismatch);
        assert!(upgrade_cap_id(&self.upgrade_cap) == upgrade.upgrade_cap,  EPackagePayloadMismatch);

        let policy = self.upgrade_cap.policy();
        self.upgrade_cap.authorize_upgrade(policy, payload.digest)
    }

    public fun commit_upgrade(self: &mut Package, upgrade: &mut Upgrade, payload: UpgradePayload, receipt: UpgradeReceipt, clock: &Clock) {
        let UpgradePayload {id,  modules: _, dependencies: _, digest: _} = payload;

        assert!(self.upgrades.contains(upgrade.id.as_inner()), EInvalidUpgrade);
        assert!(self.upgrade_cap.version() == upgrade.version, EPackageVersionError);
        assert!(self.upgrade_cap.package() != receipt.package(), EPackageReceiptMismatch);
        assert!(upgrade_cap_id(&self.upgrade_cap) == receipt.cap(), EUpgradeReceiptMismatch);
        assert!(upgrade_cap_id(&self.upgrade_cap) == upgrade.upgrade_cap,  EPackagePayloadMismatch);

        id.delete();

        upgrade.version = upgrade.version + 1;
        upgrade.executed_at_ms.fill(clock.timestamp_ms());

        self.current = receipt.package();
        self.last_upgrade_ms = clock.timestamp_ms();

        self.upgrade_cap.commit_upgrade(receipt);
    }

    // ===== Public Functions =====

    public fun upgrades(self: &Package): &vector<ID> {
        &self.upgrades
    }

    public fun upgrade_cap_id(upgrade_cap: &UpgradeCap): ID {
        let bytes = bcs::to_bytes(upgrade_cap);
        bcs::new(bytes).peel_address().to_id()
    }
}