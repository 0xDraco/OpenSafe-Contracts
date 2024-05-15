module package::package {
    use std::string::String;

    use sui::bcs;
    use sui::clock::Clock;
    use sui::package::{UpgradeCap, UpgradeTicket, UpgradeReceipt};

    public struct UpgradePayload has key {
        id: UID,
        digest: vector<u8>,
        modules: vector<u8>,
        dependencies: vector<ID>
    }

    public struct Package has store {
        current: ID,
        name: Option<String>,
        last_upgrade_ms: u64,
        upgrades: vector<ID>,
        upgrade_cap: UpgradeCap,
    }

    public struct Upgrade has key {
        id: UID,
        payload: ID,
        package: ID,
        version: u64,
        upgrade_cap: ID,
        created_at_ms: u64,
        executed_at_ms: u64
    }

    const EPackageVersionError: u64 = 0;
    const EPackagePayloadMismatch: u64 = 1;
    const EUpgradeReceiptMismatch: u64 = 2;
    const EPackageReceiptValueError: u64 = 3;

    public use fun upgrade_upgrade_cap_id as Upgrade.upgrade_cap;

    public use fun package_upgrade_cap_id as Package.upgrade_cap_id;

    public(package) fun new(name: Option<String>, upgrade_cap: UpgradeCap): Package {
        let current =  upgrade_cap.package();

        Package {
            name,
            current,
            upgrade_cap,
            last_upgrade_ms: 0,
            upgrades: vector::empty()
        }
    }

    #[allow(lint(share_owned))]
    public fun share_upgrade(upgrade: Upgrade) {
        transfer::share_object(upgrade)
    }

    #[allow(lint(share_owned))]
    public fun share_upgrade_payload(payload: UpgradePayload) {
        transfer::share_object(payload)
    }

    public(package) fun new_upgrade(
        self: &Package,
        digest: vector<u8>,
        modules: vector<u8>,
        dependencies: vector<ID>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Upgrade, UpgradePayload) {
        let upgrade_cap = self.upgrade_cap();

        let payload = UpgradePayload { 
            id: object::new(ctx),
            digest, 
            modules, 
            dependencies 
        };

        let upgrade = Upgrade { 
            id: object::new(ctx),
            executed_at_ms: 0, 
            payload: payload.id.to_inner(), 
            package: upgrade_cap.package(), 
            upgrade_cap: self.upgrade_cap_id(),
            version: self.upgrade_cap.version(),
            created_at_ms: clock.timestamp_ms(), 
        };

        (upgrade, payload)
    }

    public(package) fun authorize_upgrade(self: &mut Package, upgrade: &Upgrade, payload: &UpgradePayload): UpgradeTicket {
        let policy = self.upgrade_cap.policy();

        assert!(upgrade.payload == payload.id.to_inner(),  EPackagePayloadMismatch);
        assert!(self.upgrade_cap.version() == upgrade.version, EPackageVersionError);
        assert!(self.upgrade_cap_id() == upgrade.upgrade_cap,  EPackagePayloadMismatch);

        self.upgrade_cap.authorize_upgrade(policy, payload.digest)
    }

    public(package) fun commit_upgrade(self: &mut Package, upgrade: &mut Upgrade, payload: UpgradePayload, receipt: UpgradeReceipt, clock: &Clock) {
        let UpgradePayload {id,  modules: _, dependencies: _, digest: _} = payload;

        assert!(self.upgrade_cap_id() == receipt.cap(), EUpgradeReceiptMismatch);
        assert!(self.upgrade_cap.version() == upgrade.version, EPackageVersionError);
        assert!(self.upgrade_cap_id() == upgrade.upgrade_cap,  EPackagePayloadMismatch);
        assert!(self.upgrade_cap.package() != receipt.package(), EPackageReceiptValueError);

        upgrade.version = upgrade.version + 1;
        upgrade.executed_at_ms = clock.timestamp_ms();

        id.delete();
        self.upgrade_cap.commit_upgrade(receipt);
    }

    public(package) fun destroy(self: Package): UpgradeCap {
        let Package {current: _, name: _, last_upgrade_ms: _, upgrades: _, upgrade_cap } = self;
        upgrade_cap
    }

    // ===== View functions =====

    public fun current(self: &Package): ID {
        self.current
    }

    public fun upgrade_cap(self: &Package): &UpgradeCap {
        &self.upgrade_cap
    }

    public fun package_upgrade_cap_id(self: &Package): ID {
        let bytes = bcs::to_bytes(self.upgrade_cap());
        bcs::new(bytes).peel_address().to_id()
    }

    public fun upgrade_upgrade_cap_id(upgrade: &Upgrade): ID {
        upgrade.upgrade_cap
    }
}