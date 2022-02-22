module WenProtocol::MockToken {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;

    struct USD has copy, drop, store {}
    const PRECISION: u8 = 9;

    public fun initialize(account: &signer, amount: u128) {
        Token::register_token<USD>(account, PRECISION);
        Account::do_accept_token<USD>(account);
        if (amount > 0) {
            let token = Token::mint<USD>(account, amount);
            Account::deposit_to_self<USD>(account, token);
        };
    }

    public fun mint(account: &signer, to: address, amount: u128) {
        let token = Token::mint<USD>(account, amount);
        Account::deposit<USD>(to, token);
    }

    public fun accept_token(account: &signer) {
        Account::do_accept_token<USD>(account);
    }
}
