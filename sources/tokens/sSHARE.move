address WenProtocol {
module SSHARE {
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Event;
    use StarcoinFramework::Account;
    use StarcoinFramework::Timestamp;

    use WenProtocol::SafeMath;
    use WenProtocol::SHARE::{SHARE};

    // token
    struct SSHARE has copy, drop, store {}
    const PRECISION: u8 = 9;

    // cap
    struct SharedMintCapability has key, store { cap: Token::MintCapability<SSHARE> }
    struct SharedBurnCapability has key, store { cap: Token::BurnCapability<SSHARE> }

    // share treasury
    struct DepositEvent has drop, store { account: address, amount: u128 }
    struct MintEvent has drop, store { account: address, amount: u128 }
    struct BurnEvent has drop, store { account: address, amount: u128 }
    struct Treasury has key, store {
        token: Token::Token<SHARE>,
        locked: u128,    // total locked sshare
        deposit_events: Event::EventHandle<DepositEvent>,
        mint_events: Event::EventHandle<MintEvent>,
        burn_events: Event::EventHandle<BurnEvent>,
    }

    // error code
    const ERR_NOT_EXIST: u64 = 100;
    const ERR_ZERO_AMOUNT: u64 = 101;
    const ERR_LOCKED: u64 = 102;

    // user lock
    const LOCK_TIME: u64 = 24 * 3600;
    struct Balance has key, store {
        token: Token::Token<SSHARE>,
        locked_until: u64,
    }

    fun assert_treasury(): address {
        let owner = Token::token_address<SSHARE>();
        assert!(exists<Treasury>(owner), ERR_NOT_EXIST);
        owner
    }

    // init
    public(script) fun initialize(asigner: signer) {
        let account = &asigner;
        Token::register_token<SSHARE>(account, PRECISION);
        Account::do_accept_token<SSHARE>(account);

        let mint_cap = Token::remove_mint_capability<SSHARE>(account);
        move_to(account, SharedMintCapability {cap: mint_cap});

        let burn_cap = Token::remove_burn_capability<SSHARE>(account);
        move_to(account, SharedBurnCapability {cap: burn_cap});

        move_to(
            account,
            Treasury {
                token: Token::zero<SHARE>(),
                locked: 0,
                deposit_events: Event::new_event_handle<DepositEvent>(account),
                mint_events: Event::new_event_handle<MintEvent>(account),
                burn_events: Event::new_event_handle<BurnEvent>(account),
            },
        );
    }

    public fun total_supply(): u128 { Token::market_cap<SSHARE>() }

    public fun balance_of(addr: address): (u128, u64) acquires Balance {
        if (!exists<Balance>(addr)) {
            (0u128, 0u64)
        } else {
            let balance = borrow_global<Balance>(addr);
            (Token::value(&balance.token), balance.locked_until)
        }
    }

    public fun balance(): u128 acquires Treasury {
        let treasury = borrow_global<Treasury>(assert_treasury());
        Token::value(&treasury.token)
    }

    public fun locked_balance(): u128 acquires Treasury {
        borrow_global<Treasury>(assert_treasury()).locked
    }

    public(script) fun deposit(asigner: signer, amount: u128) acquires Treasury {
        let account = &asigner;
        let owner = assert_treasury();
        assert!(amount > 0, ERR_ZERO_AMOUNT);

        let treasury = borrow_global_mut<Treasury>(owner);
        Token::deposit(&mut treasury.token, Account::withdraw<SHARE>(account, amount));
        Event::emit_event(
            &mut treasury.deposit_events,
            DepositEvent {
                account: Signer::address_of(account),
                amount: amount,
            },
        );
    }

    public(script) fun mint(asigner: signer, amount: u128) acquires Treasury, Balance, SharedMintCapability {
        let account = &asigner;
        let owner = assert_treasury();
        assert!(amount > 0, ERR_ZERO_AMOUNT);

        // get sshare amount
        let total_supply = total_supply();
        let treasury = borrow_global<Treasury>(owner);
        if (total_supply == 0) {
            do_mint(account, owner, amount, amount);
        } else {
            // (amount * total_supply) / total_share_tokens;
            let samount = SafeMath::safe_mul_div(
                amount,
                total_supply,
                Token::value(&treasury.token),
            );
            do_mint(account, owner, amount, samount);
        };
    }

    fun do_mint(
        account: &signer,
        owner: address,
        amount: u128,   // share amount
        samount: u128,  // sshare amount
    ) acquires Treasury, Balance, SharedMintCapability {
        let addr = Signer::address_of(account);

        // init Balance
        if (!exists<Balance>(addr)) {
            move_to(
                account,
                Balance { token: Token::zero<SSHARE>(), locked_until: 0 },
            );
        };

        // Affect Balance
        let cap = borrow_global<SharedMintCapability>(owner);
        let balance = borrow_global_mut<Balance>(addr);
        Token::deposit(&mut balance.token, Token::mint_with_capability<SSHARE>(&cap.cap, samount));
        balance.locked_until = Timestamp::now_seconds() + LOCK_TIME;

        // Affect Treasury
        let treasury = borrow_global_mut<Treasury>(owner);
        treasury.locked = treasury.locked + samount;
        Token::deposit(&mut treasury.token, Account::withdraw<SHARE>(account, amount));
        Event::emit_event(
            &mut treasury.mint_events,
            MintEvent { account: addr, amount: amount },
        );
    }

    public(script) fun claim(asigner: signer) acquires Treasury, Balance {
        let account = &asigner;
        let addr = Signer::address_of(account);
        assert!(exists<Balance>(addr), ERR_NOT_EXIST);
        let balance = borrow_global_mut<Balance>(addr);
        assert!(balance.locked_until <= Timestamp::now_seconds(), ERR_LOCKED);
        let owner = assert_treasury();
        let samount = Token::value(&balance.token);

        // accept token
        if (!Account::is_accepts_token<SSHARE>(addr)) {
            Account::do_accept_token<SSHARE>(account);
        };

        // Affect Treasury
        let treasury = borrow_global_mut<Treasury>(owner);
        treasury.locked = treasury.locked - samount;

        // Affect Balance
        Account::deposit(addr, Token::withdraw(&mut balance.token, samount));
    }

    public(script) fun burn(asigner: signer, samount: u128) acquires Treasury, SharedBurnCapability {
        let account = &asigner;
        let owner = assert_treasury();
        assert!(samount > 0, ERR_ZERO_AMOUNT);

        // get share amount
        let total_supply = total_supply();
        let treasury = borrow_global_mut<Treasury>(owner);
        // (samount * total_amount) / total_supply;
        let amount = SafeMath::safe_mul_div(
            samount,
            Token::value(&treasury.token),
            total_supply,
        );

        // burn
        let cap = borrow_global<SharedBurnCapability>(owner);
        Token::burn_with_capability<SSHARE>(&cap.cap, Account::withdraw<SSHARE>(account, samount));

        // Affect Treasury
        let addr = Signer::address_of(account);
        Account::deposit(addr, Token::withdraw(&mut treasury.token, amount));
        Event::emit_event(
            &mut treasury.burn_events,
            BurnEvent { account: Signer::address_of(account), amount: amount },
        );
    }
}
}
