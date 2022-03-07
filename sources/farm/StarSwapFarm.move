// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

address WenProtocol {
module StarSwapFarm {
    use StarcoinFramework::Signer;

    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use StarSwap::TokenSwap::{Self, LiquidityToken};

    // store cap
    struct ModifyCapability<phantom PoolType, phantom AssetT> has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolType, AssetT>
    }

    public fun initialize<PoolType: store, RewardTokenT: store, X: copy+drop+store, Y: copy+drop+store>(
        account: &signer,
        reward_amount: u128,
        release_per_second: u128,
        delay: u64,
    ) {
        YieldFarming::initialize<PoolType, RewardTokenT>(account, reward_amount);
        // add asset
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            let cap = YieldFarming::add_asset<PoolType, LiquidityToken<X, Y>>(
                account, release_per_second, delay
            );
            move_to(account, ModifyCapability<PoolType, LiquidityToken<X, Y>> {cap: cap});
        } else {
            let cap = YieldFarming::add_asset<PoolType, LiquidityToken<Y, X>>(
                account, release_per_second, delay
            );
            move_to(account, ModifyCapability<PoolType, LiquidityToken<Y, X>> {cap: cap});
        };
    }

    public fun update_asset<PoolType: store, X: copy+drop+store, Y: copy+drop+store>(
        account: &signer,
        release_per_second: u128,
        alive: bool,
    ) acquires ModifyCapability {
        let addr = Signer::address_of(account);
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            let cap = borrow_global<ModifyCapability<PoolType, LiquidityToken<X, Y>>>(addr);
            YieldFarming::update_asset_with_cap<PoolType, LiquidityToken<X, Y>>(
                &cap.cap, release_per_second, alive
            );
        } else {
            let cap = borrow_global<ModifyCapability<PoolType, LiquidityToken<Y, X>>>(addr);
            YieldFarming::update_asset_with_cap<PoolType, LiquidityToken<Y, X>>(
                &cap.cap, release_per_second, alive
            );
        };
    }

    public fun deposit<PoolType: store, RewardTokenT: store, X: copy+drop+store, Y: copy+drop+store>(
        account: &signer,
        amount: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::deposit<PoolType, RewardTokenT, LiquidityToken<X, Y>>(account, amount);
        } else {
            YieldFarming::deposit<PoolType, RewardTokenT, LiquidityToken<Y, X>>(account, amount);
        };
    }

    public fun withdraw<PoolType: store, RewardTokenT: store, X: copy+drop+store, Y: copy+drop+store>(
        account: &signer,
        amount: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::withdraw<PoolType, RewardTokenT, LiquidityToken<X, Y>>(account, amount);
        } else {
            YieldFarming::withdraw<PoolType, RewardTokenT, LiquidityToken<Y, X>>(account, amount);
        };
    }

    public fun harvest<PoolType: store, RewardTokenT: store, X: copy+drop+store, Y: copy+drop+store>(
        account: &signer,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::harvest<PoolType, RewardTokenT, LiquidityToken<X, Y>>(account);
        } else {
            YieldFarming::harvest<PoolType, RewardTokenT, LiquidityToken<Y, X>>(account);
        };
    }

    public fun pending<PoolType: store, RewardTokenT: store, X: copy+drop+store, Y: copy+drop+store>(
        addr: address,
    ): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::pending<PoolType, RewardTokenT, LiquidityToken<X, Y>>(addr)
        } else {
            YieldFarming::pending<PoolType, RewardTokenT, LiquidityToken<Y, X>>(addr)
        }
    }

    public fun query_remaining_reward<PoolType: store, RewardTokenT: store>(): u128 {
        YieldFarming::query_remaining_reward<PoolType, RewardTokenT>()
    }

    public fun query_farming_asset<PoolType: store, X: copy+drop+store, Y: copy+drop+store>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::query_farming_asset<PoolType, LiquidityToken<X, Y>>()
        } else {
            YieldFarming::query_farming_asset<PoolType, LiquidityToken<Y, X>>()
        }
    }

    public fun query_stake<PoolType: store, X: copy+drop+store, Y: copy+drop+store>(addr: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::query_stake<PoolType, LiquidityToken<X, Y>>(addr)
        } else {
            YieldFarming::query_stake<PoolType, LiquidityToken<Y, X>>(addr)
        }
    }

    public fun query_farming_asset_setting<PoolType: store, X: copy+drop+store, Y: copy+drop+store>(): (u128, u128, u64, bool) {
        let order = TokenSwap::compare_token<X, Y>();
        if (order == 1) {
            YieldFarming::query_farming_asset_setting<PoolType, LiquidityToken<X, Y>>()
        } else {
            YieldFarming::query_farming_asset_setting<PoolType, LiquidityToken<Y, X>>()
        }
    }
}
}
