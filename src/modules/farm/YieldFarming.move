// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x100000 {
module YieldFarmingV1 {
    use 0x1::Token::{Self, Token};
    use 0x1::Signer;
    use 0x1::Timestamp;
    use 0x1::Account;
    use 0x1::Event;

    const EXP_MAX_SCALE: u128 = 1000000000;     // 1e9
    const ACC_PRECISION: u128 = 1000000000000;  // 1e12

    // The object of yield farming
    // RewardTokenType meaning token of yield farming
    struct HarvestEvent has drop, store { account: address, amount: u128 }
    struct Farming<PoolType, RewardTokenT> has key, store {
        treasury_token: Token<RewardTokenT>,
        events: Event::EventHandle<HarvestEvent>,
    }

    struct DepositEvent has drop, store { account: address, amount: u128 }
    struct WithdrawEvent has drop, store { account: address, amount: u128 }
    struct FarmingAsset<PoolType, AssetT> has key, store {
        total_amount: u128,             // Total stake AssetT
        last_update_timestamp: u64,     // update at update_pool
        release_per_second: u128,       // Release count per seconds
        acc_reward_per_share: u128,     // Accumulated Reward per share.
        start_time: u64,                // Start time, by seconds
        alive: bool,                    // Representing the pool is alive, false: not alive, true: alive.
        withdraw_events: Event::EventHandle<WithdrawEvent>,
        deposit_events: Event::EventHandle<DepositEvent>,
    }

    // To store user's asset token
    struct Stake<PoolType, AssetT> has key, store {
        asset: Token<AssetT>,
        debt: u128,     // update at deposit withdraw harvest
    }

    // Capability to modify parameter such as period and release amount
    struct ParameterModifyCapability<PoolType, AssetT> has key, store {}

    // error code
    const ERR_NOT_AUTHORIZED: u64 = 100;
    const ERR_REWARDTOKEN_SCALING_FACTOR_OVERFLOW: u64 = 101;
    const ERR_REPEATED_INITIALIZATION: u64 = 102;
    const ERR_REPEATED_ADD_ASSET: u64 = 103;
    const ERR_STILL_CONTAIN_A_VAULT: u64 = 104;
    const ERR_FARM_NOT_ALIVE: u64 = 105;
    const ERR_FARM_NOT_START: u64 = 106;

    fun assert_owner<T: store>(account: &signer): address {
        let owner = Token::token_address<T>();
        assert(Signer::address_of(account) == owner, ERR_NOT_AUTHORIZED);
        owner
    }

    fun pool_type_issuer<PoolType: store>(): address { Token::token_address<PoolType>() }

    fun auto_accept_reward<RewardTokenT: store>(account: &signer) {
        if (!Account::is_accepts_token<RewardTokenT>(Signer::address_of(account))) {
            Account::do_accept_token<RewardTokenT>(account);
        };
    }

    // Initialization
    // only PoolType issuer can initialize
    public fun initialize<PoolType: store, RewardTokenT: store>(account: &signer, amount: u128) {
        let owner = assert_owner<PoolType>(account);
        assert(
            Token::scaling_factor<RewardTokenT>() <= EXP_MAX_SCALE,
            ERR_REWARDTOKEN_SCALING_FACTOR_OVERFLOW,
        );
        assert(
            !exists<Farming<PoolType, RewardTokenT>>(owner),
            ERR_REPEATED_INITIALIZATION,
        );
        move_to(
            account,
            Farming<PoolType, RewardTokenT> {
                treasury_token: Account::withdraw<RewardTokenT>(account, amount),
                events: Event::new_event_handle<HarvestEvent>(account),
            },
        );
    }

    // Add asset pools
    // only PoolType issuer can add asset
    public fun add_asset<PoolType: store, AssetT: store>(
        account: &signer,
        release_per_second: u128,
        delay: u64,
    ): ParameterModifyCapability<PoolType, AssetT> {
        let owner = assert_owner<PoolType>(account);
        assert(
            !exists<FarmingAsset<PoolType, AssetT>>(owner),
            ERR_REPEATED_ADD_ASSET,
        );
        let now_seconds = Timestamp::now_seconds();
        move_to(
            account,
            FarmingAsset<PoolType, AssetT> {
                total_amount: 0,
                release_per_second: release_per_second,
                last_update_timestamp: now_seconds + delay,
                start_time: now_seconds + delay,
                acc_reward_per_share: 0,
                alive: true,
                withdraw_events: Event::new_event_handle<WithdrawEvent>(account),
                deposit_events: Event::new_event_handle<DepositEvent>(account)
            },
        );
        ParameterModifyCapability<PoolType, AssetT> {}
    }

    public fun update_asset_with_cap<PoolType: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        release_per_second: u128,
        alive: bool,
    ) acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.release_per_second = release_per_second;
        farming_asset.alive = alive;
    }

    fun calculate_reward_per_share(
        time_period: u64,
        release_per_second: u128,
        total_amount: u128,
    ): u128 {
        let reward_amount = (time_period as u128) * release_per_second;
        reward_amount * ACC_PRECISION / total_amount
    }

    // update pool
    public fun update_pool<PoolType: store, AssetT: store>() acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        let now_seconds = Timestamp::now_seconds();

        if (farming_asset.last_update_timestamp < now_seconds && farming_asset.alive) {
            if (farming_asset.total_amount > 0) {
                let reward_per_share = calculate_reward_per_share(
                    now_seconds - farming_asset.last_update_timestamp,
                    farming_asset.release_per_second,
                    farming_asset.total_amount,
                );
                farming_asset.acc_reward_per_share = farming_asset.acc_reward_per_share + reward_per_share;
            };
            farming_asset.last_update_timestamp = now_seconds;
        };
    }

    public fun pending<PoolType: store, RewardTokenT: store, AssetT: store>(
        addr: address
    ): u128 acquires FarmingAsset, Stake {
        let broker = pool_type_issuer<PoolType>();
        if (exists<Stake<PoolType, AssetT>>(addr)) {
            let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
            let stake = borrow_global<Stake<PoolType, AssetT>>(addr);
            let total_deposit = Token::value<AssetT>(&stake.asset);
            let now_seconds = Timestamp::now_seconds();
            let acc_reward_per_share = farming_asset.acc_reward_per_share;
            if (now_seconds > farming_asset.last_update_timestamp && farming_asset.total_amount > 0) {
                let reward_per_share = calculate_reward_per_share(
                    now_seconds - farming_asset.last_update_timestamp,
                    farming_asset.release_per_second,
                    farming_asset.total_amount,
                );
                acc_reward_per_share = acc_reward_per_share + reward_per_share;
            };
            total_deposit * acc_reward_per_share / ACC_PRECISION - stake.debt
        } else {
            0
        }
    }

    // Harvest yield farming token from stake
    fun do_harvest<PoolType: store, RewardTokenT: store, AssetT: store>(
        addr: address,
    ): Token<RewardTokenT> acquires Farming, FarmingAsset, Stake {
        let broker = pool_type_issuer<PoolType>();
        let total_deposit = query_stake<PoolType, AssetT>(addr);
        let reward_token;
        if (total_deposit > 0) {
            let stake = borrow_global<Stake<PoolType, AssetT>>(addr);
            let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
            let debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;
            let pending = debt - stake.debt;
            if (pending > 0) {
                // Affect treasury_token
                let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
                reward_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, pending);
                Event::emit_event(
                    &mut farming.events,
                    HarvestEvent { amount: pending, account: addr },
                );
            } else {
                reward_token = Token::zero<RewardTokenT>();
            }
        } else {
            reward_token = Token::zero<RewardTokenT>();
        };
        reward_token
    }

    public fun harvest<PoolType: store, RewardTokenT: store, AssetT: store>(
        account: &signer,
    ) acquires Farming, FarmingAsset, Stake {
        let addr = Signer::address_of(account);
        let broker = pool_type_issuer<PoolType>();
        update_pool<PoolType, AssetT>();
        let reward_token = do_harvest<PoolType, RewardTokenT, AssetT>(addr);

        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(addr);

        // Affect debt
        let total_deposit = Token::value<AssetT>(&stake.asset);
        stake.debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;

        // Affect reward token
        auto_accept_reward<RewardTokenT>(account);
        Account::deposit(addr, reward_token);
    }

    // Deposit amount of token in order to get yield farming token
    public fun deposit<PoolType: store, RewardTokenT: store, AssetT: store>(
        account: &signer,
        amount: u128,
    ) acquires Farming, FarmingAsset, Stake {
        let addr = Signer::address_of(account);
        let broker = pool_type_issuer<PoolType>();
        let now_seconds = Timestamp::now_seconds();
        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        assert(farming_asset.alive, ERR_FARM_NOT_ALIVE);
        assert(now_seconds >= farming_asset.start_time, ERR_FARM_NOT_START);

        // update pool and harvest
        update_pool<PoolType, AssetT>();
        let reward_token = do_harvest<PoolType, RewardTokenT, AssetT>(addr);

        // update total deposit amount.
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.total_amount = farming_asset.total_amount + amount;
        Event::emit_event(
            &mut farming_asset.deposit_events,
            DepositEvent { account: addr, amount: amount },
        );

        // init stake info
        if (!exists<Stake<PoolType, AssetT>>(addr)) {
            move_to(
                account,
                Stake<PoolType, AssetT> {
                    asset: Token::zero<AssetT>(),
                    debt: 0,
                },
            );
        };

        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(addr);
        // Deposit asset
        Token::deposit<AssetT>(&mut stake.asset, Account::withdraw<AssetT>(account, amount));
        // Affect debt
        let total_deposit = Token::value<AssetT>(&stake.asset);
        stake.debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;

        // Affect reward token
        auto_accept_reward<RewardTokenT>(account);
        Account::deposit(addr, reward_token);
    }

    // Withdraw asset from farming pool
    public fun withdraw<PoolType: store, RewardTokenT: store, AssetT: store>(
        account: &signer,
        amount: u128
    ) acquires Farming, FarmingAsset, Stake {
        let addr = Signer::address_of(account);
        let broker = pool_type_issuer<PoolType>();

        // update pool and harvest
        update_pool<PoolType, AssetT>();
        let reward_token = do_harvest<PoolType, RewardTokenT, AssetT>(addr);

        // update total deposit amount.
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.total_amount = farming_asset.total_amount - amount;
        Event::emit_event(
            &mut farming_asset.withdraw_events,
            WithdrawEvent { account: addr, amount: amount },
        );

        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(addr);
        // Withdraw asset
        let asset_token = Token::withdraw<AssetT>(&mut stake.asset, amount);
        // Affect debt
        let total_deposit = Token::value<AssetT>(&stake.asset);
        stake.debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;

        // Affect reward token
        auto_accept_reward<RewardTokenT>(account);
        Account::deposit(addr, reward_token);
        Account::deposit(addr, asset_token);

        if (total_deposit == 0) {
            let Stake<PoolType, AssetT> {
                asset, debt: _,
            } = move_from<Stake<PoolType, AssetT>>(addr);
            assert(Token::value<AssetT>(&asset) == 0, ERR_STILL_CONTAIN_A_VAULT);
            Token::destroy_zero<AssetT>(asset);
        };
    }

    // Query rewardable token
    public fun query_remaining_reward<PoolType: store, RewardTokenT: store>(): u128 acquires Farming {
        let broker = pool_type_issuer<PoolType>();
        let farming = borrow_global<Farming<PoolType, RewardTokenT>>(broker);
        Token::value<RewardTokenT>(&farming.treasury_token)
    }

    // Query all stake amount
    public fun query_farming_asset<PoolType: store, AssetT: store>(): u128 acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        borrow_global<FarmingAsset<PoolType, AssetT>>(broker).total_amount
    }

    // Query asset settings
    public fun query_farming_asset_setting<PoolType: store, AssetT: store>(
    ): (u128, u128, u64, bool) acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        (
            farming_asset.release_per_second,
            farming_asset.acc_reward_per_share,
            farming_asset.start_time,
            farming_asset.alive,
        )
    }

    // Query stake amount from user
    public fun query_stake<PoolType: store, AssetT: store>(addr: address): u128 acquires Stake {
        if (exists<Stake<PoolType, AssetT>>(addr)) {
            let stake = borrow_global<Stake<PoolType, AssetT>>(addr);
            Token::value<AssetT>(&stake.asset)
        } else {
            0u128
        }
    }
}
}
