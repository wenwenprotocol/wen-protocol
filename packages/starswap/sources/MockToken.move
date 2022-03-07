address StarSwap {
module MockToken {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;

    struct USD has copy, drop, store {}
    const PRECISION: u8 = 9;

    public fun initialize(account: &signer) {
        Token::register_token<USD>(account, PRECISION);
        Account::do_accept_token<USD>(account);
    }

    public(script) fun init(account: signer) {
        initialize(&account);
    }
}
}
