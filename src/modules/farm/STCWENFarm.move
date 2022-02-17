// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x100000 {
module STCWENFarmV2 {
    use 0x1::Signer;
    use 0x1::STC::STC;

    use 0x100000::WEN::WEN;
    use 0x100000::SHARE::{Self, SHARE};
    use 0x100000::StarSwapFarm;

    struct STC_WEN has store {}

    const RELEASE_PER_SECOND: u128 = 100000000;             // 0.1 share/s
    const REWARD_AMOUNT: u128 = 1000 * 10000 * 1000000000;  // 10m
    const DELAY: u64 = 0;

    public(script) fun initialize(account: signer) {
        SHARE::mint(&account, Signer::address_of(&account), REWARD_AMOUNT);
        StarSwapFarm::initialize<STC_WEN, SHARE, STC, WEN>(
            &account,
            REWARD_AMOUNT,
            RELEASE_PER_SECOND,
            DELAY,
        );
    }

    public(script) fun update_asset(
        account: signer,
        release_per_second: u128,
        alive: bool,
    ) {
        StarSwapFarm::update_asset<STC_WEN, STC, WEN>(&account, release_per_second, alive);
    }

    public(script) fun deposit(account: signer, amount: u128) {
        StarSwapFarm::deposit<STC_WEN, SHARE, STC, WEN>(&account, amount);
    }

    public(script) fun withdraw(account: signer, amount: u128) {
        StarSwapFarm::withdraw<STC_WEN, SHARE, STC, WEN>(&account, amount);
    }

    public(script) fun harvest(account: signer) {
        StarSwapFarm::harvest<STC_WEN, SHARE, STC, WEN>(&account);
    }

    public fun pending(addr: address): u128 {
        StarSwapFarm::pending<STC_WEN, SHARE, STC, WEN>(addr)
    }

    public fun query_remaining_reward(): u128 {
        StarSwapFarm::query_remaining_reward<STC_WEN, SHARE>()
    }

    public fun query_farming_asset(): u128 {
        StarSwapFarm::query_farming_asset<STC_WEN, STC, WEN>()
    }

    public fun query_stake(addr: address): u128 {
        StarSwapFarm::query_stake<STC_WEN, STC, WEN>(addr)
    }

    public fun query_farming_asset_setting(): (u128, u128, u64, bool) {
        StarSwapFarm::query_farming_asset_setting<STC_WEN, STC, WEN>()
    }
}
}