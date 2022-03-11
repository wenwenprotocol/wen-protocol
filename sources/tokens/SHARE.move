address WenProtocol {
module SHARE {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;

    const PRECISION: u8 = 9;
    const MAX_SUPPLY: u128 = 1 * 1000 * 1000 * 1000; // 1b
    const ERR_TOO_BIG_AMOUNT: u64 = 100;

    struct SHARE has copy, drop, store {}

    // init
    public fun initialize(
        account: &signer,
    ) {
        Token::register_token<SHARE>(account, PRECISION);
        Account::do_accept_token<SHARE>(account);
    }

    public fun mint(account: &signer, to: address, amount: u128) {
        assert!(get_max_supply() >= (Token::market_cap<SHARE>() + amount), ERR_TOO_BIG_AMOUNT);
        Account::deposit<SHARE>(to, Token::mint<SHARE>(account, amount));
    }

    public fun get_max_supply(): u128 {
        Token::scaling_factor<SHARE>() * MAX_SUPPLY
    }
}

module SHARETeamTreasury {
    use StarcoinFramework::Treasury;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use WenProtocol::SHARE::{Self, SHARE};

    const LOCK_TIME: u64 = 3 * 365 * 86400; // 3 years
    const LOCK_PERCENT: u128 = 20;          // 20%

    public(script) fun initialize(account: signer) {
        let amount = SHARE::get_max_supply() * LOCK_PERCENT / 100;
        let token = Token::mint<SHARE>(&account, amount);
        let cap = Treasury::initialize<SHARE>(&account, token);
        let linear_cap = Treasury::issue_linear_withdraw_capability<SHARE>(
            &mut cap,
            amount,
            LOCK_TIME,
        );
        Treasury::add_linear_withdraw_capability<SHARE>(&account, linear_cap);
        Treasury::destroy_withdraw_capability<SHARE>(cap);
    }

    public(script) fun withdraw(account: signer, to: address) {
        Account::deposit<SHARE>(to, Treasury::withdraw_by_linear<SHARE>(&account));
    }

    public fun balance(): u128 { Treasury::balance<SHARE>() }
}
}
