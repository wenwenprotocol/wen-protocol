// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

address WenProtocol {
module WithdrawerWithKiko {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Event;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Token::{Self, Token};

    use WenProtocol::WEN::WEN;
    use WenProtocol::SHARE::SHARE;
    use WenProtocol::SSHARE;
    use WenProtocol::STCLendingPoolV2;

    use KikoSwap::SwapRouter;

    struct DepositEvent has drop, store { amount: u128 }
    struct WithdrawEvent has drop, store { to: address, amount: u128 }
    struct Reserve has key, store {
        token: Token<WEN>,
        withdraw_events: Event::EventHandle<WithdrawEvent>,
        deposit_events: Event::EventHandle<DepositEvent>,
    }
    struct SwapInfo has key, store {
        amount_r: u128, // reserve
        amount_x: u128, // wen
        amount_y: u128, // stc
        amount_z: u128, // share
        last_update: u64,
    }
    const RESERVE_PERCENT: u128 = 20;   // 20%

    const ERR_ACCEPT_TOKEN: u64 = 100;
    const ERR_NOT_FEE_ADDRESS: u64 = 101;
    const ERR_STILL_CONTAIN_A_VAULT: u64 = 102;

    fun admin(): address { @WenProtocol }

    public(script) fun initialize(account: signer){
        move_to(
            &account,
            Reserve {
                token: Token::zero<WEN>(),
                withdraw_events: Event::new_event_handle<WithdrawEvent>(&account),
                deposit_events: Event::new_event_handle<DepositEvent>(&account),
            },
        );
        move_to(
            &account,
            SwapInfo {
                amount_r: 0,
                amount_x: 0,
                amount_y: 0,
                amount_z: 0,
                last_update: 0,
            },
        );
    }

    public fun balance(): u128 acquires Reserve {
        let reserve = borrow_global<Reserve>(admin());
        Token::value(&reserve.token)
    }

    public fun swap_info(): (u128, u128, u128, u128, u64) acquires SwapInfo {
        let info = borrow_global<SwapInfo>(admin());
        (info.amount_r, info.amount_x, info.amount_y, info.amount_z, info.last_update)
    }

    // admin
    public(script) fun withdraw(account: signer, to: address, amount: u128) acquires Reserve {
        assert!(Account::is_accepts_token<WEN>(to), ERR_ACCEPT_TOKEN);
        let reserve = borrow_global_mut<Reserve>(Signer::address_of(&account));
        Account::deposit(to, Token::withdraw(&mut reserve.token, amount));
        Event::emit_event(&mut reserve.withdraw_events, WithdrawEvent { to, amount });
    }

    // fee to
    public(script) fun withdraw_and_swap(account: signer) acquires Reserve, SwapInfo {
        // lending pool accrue
        STCLendingPoolV2::accrue();

        // fee info
        let (fee_address, fees_earned, _) = STCLendingPoolV2::fee_info();
        assert!(Signer::address_of(&account) == fee_address, ERR_NOT_FEE_ADDRESS);

        if (fees_earned > 0) {
            // step1. withdraw
            do_withdraw_fee(&account, fees_earned);
            // step2. swap
            let share_amount = do_swap(&account, fees_earned);
            // step3. deposit to sshare
            SSHARE::deposit(account, share_amount);
        };
    }

    // step1
    fun do_withdraw_fee(account: &signer, amount: u128) {
        let (_, _, balance) = STCLendingPoolV2::borrow_info();
        if (amount > balance) {
            // deposit to lendingpool
            STCLendingPoolV2::do_deposit(account, amount);
        };
        // withdraw fees to account
        STCLendingPoolV2::do_withdraw();
    }

    // step2
    fun do_swap(account: &signer, amount: u128): u128 acquires Reserve, SwapInfo {
        // check reserve
        let reserve_amount = amount * RESERVE_PERCENT / 100;
        if (reserve_amount > 0) {
            let reserve = borrow_global_mut<Reserve>(admin());
            Token::deposit(&mut reserve.token, Account::withdraw<WEN>(account, reserve_amount));
            Event::emit_event(&mut reserve.deposit_events, DepositEvent { amount: reserve_amount });
        };

        let amount_x = amount - reserve_amount;
        // wen -> stc
        let amount_y = SwapRouter::swap_exact_token_for_token<WEN, STC>(account, amount_x, 0);
        // stc -> share
        let amount_z = SwapRouter::swap_exact_token_for_token<STC, SHARE>(account, amount_y, 0);

        let info = borrow_global_mut<SwapInfo>(admin());
        info.amount_r = reserve_amount;
        info.amount_x = amount_x;
        info.amount_y = amount_y;
        info.amount_z = amount_z;
        info.last_update = Timestamp::now_seconds();
        amount_z
    }

    // destroy
    public(script) fun destroy(account: signer) acquires Reserve, SwapInfo {
        let addr = Signer::address_of(&account);
        let Reserve {
            token,
            withdraw_events,
            deposit_events,
        } = move_from<Reserve>(addr);
        assert!(Token::value(&token) == 0, ERR_STILL_CONTAIN_A_VAULT);
        Token::destroy_zero(token);
        Event::destroy_handle<DepositEvent>(deposit_events);
        Event::destroy_handle<WithdrawEvent>(withdraw_events);

        let SwapInfo {
            amount_r: _,
            amount_x: _,
            amount_y: _,
            amount_z: _,
            last_update: _,
        } = move_from<SwapInfo>(addr);
    }
}
}
