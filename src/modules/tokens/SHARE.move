address 0x100000 {
module SHARE {
    use 0x1::Token;
    use 0x1::Account;

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
        let max_supply = get_max_supply();
        let total_supply = Token::market_cap<SHARE>();
        assert(max_supply >= (total_supply + amount), ERR_TOO_BIG_AMOUNT);
        let token = Token::mint<SHARE>(account, amount);
        Account::deposit<SHARE>(to, token);
    }

    public fun get_max_supply(): u128 {
        let scaling_factor = Token::scaling_factor<SHARE>();
        MAX_SUPPLY * scaling_factor
    }
}

module SHARETeamTreasury {
    use 0x1::Treasury;
    use 0x1::Account;
    use 0x1::Token;
    use 0x100000::SHARE::{Self, SHARE};

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
        let token = Treasury::withdraw_by_linear<SHARE>(&account);
        Account::deposit<SHARE>(to, token);
    }

    public fun balance(): u128 {
        Treasury::balance<SHARE>()
    }
}
}
