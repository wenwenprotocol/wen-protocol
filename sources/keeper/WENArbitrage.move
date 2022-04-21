// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

module WenProtocol::WENArbitrage {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Vector;

    use WenProtocol::WEN::WEN;
    use WenProtocol::LendingPoolV2;

    use KikoSwap::SwapRouter;

    use StarSwap::TokenSwapRouter;
    use StarSwap::TokenSwapScripts;

    /// order = 1
    /// starswap stc-token kikoswap token-stc
    /// order = 2
    /// kikoswap stc-token starswap token-stc
    public(script) fun swap(account: signer, order: u128, amount: u128) {
        if (order == 1) {
            let amount_out = TokenSwapScripts::get_amount_out<STC, WEN>(amount);
            TokenSwapRouter::swap_exact_token_for_token<STC, WEN>(&account, amount, amount_out);
            SwapRouter::swap_exact_token_for_token<WEN, STC>(&account, amount_out, 0);
        } else if (order == 2) {
            let amount_out = SwapRouter::swap_exact_token_for_token<STC, WEN>(&account, amount, 0);
            TokenSwapRouter::swap_exact_token_for_token<WEN, STC>(
                &account,
                amount_out,
                TokenSwapScripts::get_amount_out<WEN, STC>(amount_out),
            );
        };
    }

    public(script) fun borrow_and_sell<PoolType: store>(
        account: signer,
        collateral_amount: u128,
        borrow_amount: u128,
        amount_to_star: u128,
        amount_to_kiko: u128,
    ) {
        let addr = Signer::address_of(&account);
        if (collateral_amount > 0 || borrow_amount > 0) {
            let actions = Vector::empty<u8>();
            // ACTION_ADD_COLLATERAL
            Vector::push_back<u8>(&mut actions, 1);
            // ACTION_BORROW
            Vector::push_back<u8>(&mut actions, 3);
            LendingPoolV2::cook<PoolType, STC, WEN>(
                &account,
                &actions,
                collateral_amount,
                0,
                @0x0,
                borrow_amount,
                addr,
                0,
                @0x0,
            );
        };
        if (amount_to_star > 0) {
            TokenSwapRouter::swap_exact_token_for_token<WEN, STC>(
                &account,
                amount_to_star,
                TokenSwapScripts::get_amount_out<WEN, STC>(amount_to_star),
            );
        };
        if (amount_to_kiko > 0) {
            SwapRouter::swap_exact_token_for_token<WEN, STC>(&account, amount_to_kiko, 0);
        };
    }

    public(script) fun buy_and_repay<PoolType: store>(
        account: signer,
        amount_to_star: u128,
        amount_to_kiko: u128,
        repay_part: u128,
        remove_collateral_amount: u128,
    ) {
        let addr = Signer::address_of(&account);
        if (amount_to_star > 0) {
            TokenSwapRouter::swap_exact_token_for_token<STC, WEN>(
                &account,
                amount_to_star,
                TokenSwapScripts::get_amount_out<STC, WEN>(amount_to_star),
            );
        };
        if (amount_to_kiko > 0) {
            SwapRouter::swap_exact_token_for_token<STC, WEN>(&account, amount_to_kiko, 0);
        };
        let (_, total_part) = LendingPoolV2::position<PoolType>(addr);
        if (repay_part > 0 && repay_part <= total_part) {
            let actions = Vector::empty<u8>();
            // ACTION_REPAY
            Vector::push_back<u8>(&mut actions, 4);
            // ACTION_REMOVE_COLLATERAL
            Vector::push_back<u8>(&mut actions, 2);
            LendingPoolV2::cook<PoolType, STC, WEN>(
                &account,
                &actions,
                0,
                remove_collateral_amount,
                addr,
                0,
                @0x0,
                repay_part,
                addr,
            );
        };
    }
}
