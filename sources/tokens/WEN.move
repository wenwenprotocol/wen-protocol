address WenProtocol {
module WEN {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Errors;

    struct WEN has copy, drop, store {}
    struct Minting has key, store {
        time: u64,
        amount: u128,
    }

    const PRECISION: u8 = 9;
    const MINTING_PERIOD: u64 = 24 * 3600; // 24 hours
    const MINTING_INCREASE: u128 = 15000;
    const MINTING_PRECISION: u128 = 100000;

    const ERR_MINT_EXCEED: u64 = 401;
    const EDEPRECATED_FUNCTION: u64 = 404;

    // init
    public fun initialize(
        account: &signer,
    ) {
        Token::register_token<WEN>(account, PRECISION);
        Account::do_accept_token<WEN>(account);
        initialize_minting(account);
    }

    public fun initialize_minting(account: &signer) {
        move_to(account, Minting {time: Timestamp::now_seconds(), amount: 0});
    }

    // deprecated
    public fun mint(_account: &signer, _to: address, _amount: u128) {
        abort Errors::deprecated(EDEPRECATED_FUNCTION)
    }

    public fun mint_to(account: &signer, to: address, amount: u128) acquires Minting {
        let minting = borrow_global_mut<Minting>(Token::token_address<WEN>());
        let total_supply = Token::market_cap<WEN>();
        let now = Timestamp::now_seconds();
        let total_minted_amount;
        if (now - minting.time > MINTING_PERIOD) {
            total_minted_amount = amount;
        } else {
            total_minted_amount = minting.amount + amount;
        };
        let max_mint_amount = total_supply * MINTING_INCREASE / MINTING_PRECISION;
        assert!(total_supply == 0 || max_mint_amount >= total_minted_amount, ERR_MINT_EXCEED);

        minting.time = now;
        minting.amount = total_minted_amount;

        let token = Token::mint<WEN>(account, amount);
        Account::deposit<WEN>(to, token);
    }
}
}
