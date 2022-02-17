address 0x100000 {
module MockToken {
    use 0x1::Token;
    use 0x1::Account;

    struct USD has copy, drop, store {}
    const PRECISION: u8 = 9;

    public fun initialize(account: &signer) {
        Token::register_token<USD>(account, PRECISION);
        Account::do_accept_token<USD>(account);
    }

    public(script) fun init(account: signer) {
        initialize(&account);
    }

    public fun mint(account: &signer, to: address, amount: u128) {
        let token = Token::mint<USD>(account, amount);
        Account::deposit<USD>(to, token);
    }
}
}
