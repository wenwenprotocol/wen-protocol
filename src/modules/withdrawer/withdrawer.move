// Copyright (c) The Starcoin Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x100000 {
module WithdrawerV1 {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Event;
    use 0x1::STC::STC;
    use 0x1::Timestamp;
    use 0x1::Token::{Self, Token};

    use 0x100000::Permission;
    use 0x100000::WEN::WEN;
    use 0x100000::SHARE::SHARE;
    use 0x100000::SSHARE;
    use 0x100000::LendingPool;
    use 0x100000::STCLendingPoolV1::STC_POOL;

    // TokenSwap address on barnard: 0x4783d08fb16990bd35d83f3e23bf93b8
    use 0x300000::TokenSwapRouter;
    use 0x300000::TokenSwapScripts;

    struct DepositEvent has drop, store { addr: address, amount: u128 }
    struct WithdrawEvent has drop, store { addr: address, amount: u128 }
    struct Treasury has key, store {
        token: Token<WEN>,  // store wen for lendingpool
        fees: u128,         // store amount for swap
        last_wen: u128,
        last_stc: u128,
        last_share: u128,
        last_swap: u64,
        withdraw_events: Event::EventHandle<WithdrawEvent>,
        deposit_events: Event::EventHandle<DepositEvent>,
    }

    // Permission
    struct Verified has store {}

    const ERR_NOT_FEE_ADDRESS: u64 = 100;
    const ERR_NOT_VERIFIED: u64 = 101;

    fun admin(): address { @0x100000 }

    public(script) fun initialize(account: signer, amount: u128) acquires Treasury {
        Permission::register_permission<Verified>(&account);
        move_to(
            &account,
            Treasury {
                token: Token::zero<WEN>(),
                fees: 0,
                last_wen: 0,
                last_stc: 0,
                last_share: 0,
                last_swap: 0,
                withdraw_events: Event::new_event_handle<WithdrawEvent>(&account),
                deposit_events: Event::new_event_handle<DepositEvent>(&account),
            },
        );
        if (amount > 0) {
            deposit(account, amount);
        };
    }

    public(script) fun add_verifier(account: signer, addr: address) {
        Permission::add<Verified>(&account, addr);
    }

    public(script) fun remove_verifier(account: signer, addr: address) {
        Permission::remove<Verified>(&account, addr);
    }

    public(script) fun deposit(account: signer, amount: u128) acquires Treasury {
        let treasury = borrow_global_mut<Treasury>(admin());
        Token::deposit(&mut treasury.token, Account::withdraw<WEN>(&account, amount));
        Event::emit_event(
            &mut treasury.deposit_events,
            DepositEvent {
                addr: Signer::address_of(&account),
                amount: amount,
            },
        );
    }

    public fun balance(): u128 acquires Treasury {
        let treasury = borrow_global<Treasury>(admin());
        Token::value(&treasury.token)
    }

    public fun swap_info(): (u128, u128, u128, u64) acquires Treasury {
        let treasury = borrow_global<Treasury>(admin());
        (treasury.last_wen, treasury.last_stc, treasury.last_share, treasury.last_swap)
    }

    fun transfer(addr: address, amount: u128) acquires Treasury {
        let treasury = borrow_global_mut<Treasury>(admin());
        Account::deposit(addr, Token::withdraw(&mut treasury.token, amount));
        Event::emit_event(
            &mut treasury.withdraw_events,
            WithdrawEvent { addr, amount },
        );
    }

    fun do_withdraw_fee(account: &signer, amount: u128) acquires Treasury {
        let addr = Signer::address_of(account);
        let (_, _, balance) = LendingPool::borrow_info<STC_POOL, WEN>();
        if (amount > balance) {
            transfer(addr, amount);
            // deposit to lendingpool
            LendingPool::deposit<STC_POOL, WEN>(account, amount);
        };

        // withdraw fees to account
        LendingPool::withdraw<STC_POOL, WEN>();
    }

    // withdraw wen from lending pool
    // lending pool fee_to call this
    public(script) fun withdraw_fee(account: signer) acquires Treasury {
        LendingPool::accrue<STC_POOL, WEN>();

        let (fee_address, fees_earned, _) = LendingPool::fee_info<STC_POOL>();
        assert(Signer::address_of(&account) == fee_address, ERR_NOT_FEE_ADDRESS);

        do_withdraw_fee(&account, fees_earned);

        let treasury = borrow_global_mut<Treasury>(admin());
        treasury.fees = fees_earned;
        deposit(account, fees_earned);
    }

    fun do_swap_wen_for_share(account: &signer, amount: u128): u128 acquires Treasury {
        // swap wen -> stc
        let stc_amount = TokenSwapScripts::get_amount_out<WEN, STC>(amount);
        TokenSwapRouter::swap_exact_token_for_token<WEN, STC>(account, amount, stc_amount);

        // swap stc -> share
        let share_amount = TokenSwapScripts::get_amount_out<STC, SHARE>(stc_amount);
        TokenSwapRouter::swap_exact_token_for_token<STC, SHARE>(account, stc_amount, share_amount);

        let treasury = borrow_global_mut<Treasury>(admin());
        treasury.last_wen = amount;
        treasury.last_stc = stc_amount;
        treasury.last_share = share_amount;
        treasury.last_swap = Timestamp::now_seconds();
        share_amount
    }

    public(script) fun swap_wen_for_share(account: signer) acquires Treasury {
        let addr = Signer::address_of(&account);
        assert(Permission::can<Verified>(addr), ERR_NOT_VERIFIED);

        let fees = borrow_global<Treasury>(admin()).fees;

        if (fees > 0) {
            transfer(addr, fees);
            let share_amount = do_swap_wen_for_share(&account, fees);
            let treasury = borrow_global_mut<Treasury>(admin());
            treasury.fees = 0;
            // deposit to sshare
            SSHARE::deposit(account, share_amount);
        };
    }

    public(script) fun swap_wen_for_share_v2(account: signer, amount: u128) acquires Treasury {
        let addr = Signer::address_of(&account);
        assert(Permission::can<Verified>(addr), ERR_NOT_VERIFIED);

        if (amount == 0) {
            amount = borrow_global<Treasury>(admin()).fees;
        };

        if (amount > 0) {
            transfer(addr, amount);
            let share_amount = do_swap_wen_for_share(&account, amount);

            let treasury = borrow_global_mut<Treasury>(admin());
            treasury.fees = 0;
            // deposit to sshare
            SSHARE::deposit(account, share_amount);
        };
    }

    public(script) fun withdraw_and_swap(account: signer) acquires Treasury {
        let addr = Signer::address_of(&account);
        LendingPool::accrue<STC_POOL, WEN>();
        let (fee_address, fees_earned, _) = LendingPool::fee_info<STC_POOL>();

        assert(Permission::can<Verified>(addr), ERR_NOT_VERIFIED);
        assert(addr == fee_address, ERR_NOT_FEE_ADDRESS);

        if (fees_earned > 0) {
            do_withdraw_fee(&account, fees_earned);
            let share_amount = do_swap_wen_for_share(&account, fees_earned);
            // deposit to sshare
            SSHARE::deposit(account, share_amount);
        };
    }
}
}
