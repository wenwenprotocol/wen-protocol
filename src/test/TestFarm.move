address 0x100000 {
module TestFarm {
    use 0x1::Signer;
    use 0x100000::YieldFarmingV1 as YieldFarming;

    struct STC_WEN has store {}
    struct Cap<T1, T2> has key, store {
        cap: YieldFarming::ParameterModifyCapability<T1, T2>
    }

    public fun add_asset<AssetT: store>(
        account: &signer,
        release_per_second: u128,
        delay: u64,
    ) {
        let cap = YieldFarming::add_asset<STC_WEN, AssetT>(
            account, release_per_second, delay);
        move_to(account, Cap<STC_WEN, AssetT> {cap: cap});
    }

    public fun update_asset<AssetT: store>(
        account: &signer,
        release_per_second: u128,
        alive: bool,
    ) acquires Cap {
        let cap = borrow_global<Cap<STC_WEN, AssetT>>(
            Signer::address_of(account)
        );
        YieldFarming::update_asset_with_cap<STC_WEN, AssetT>(
            &cap.cap,
            release_per_second,
            alive,
        );
    }
}
}
