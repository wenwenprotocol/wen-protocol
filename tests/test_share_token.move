//! account: alice, 0x123, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init share
//! sender: owner
script {
    use 0x100000::SHARE;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
    }
}

// accept SHARE
//! new-transaction
//! sender: alice
script {
    use 0x1::Account;
    use 0x100000::SHARE::SHARE;

    fun main(sender: signer) {
        Account::do_accept_token<SHARE>(&sender);
    }
}

// mint wen to alice
//! new-transaction
//! sender: owner
address alice = {{alice}};
script {
    use 0x100000::SHARE;

    fun main(sender: signer) {
        // 1000 SHARE
        SHARE::mint(&sender, @alice, 1000 * 1000 * 1000 * 1000);
    }
}

// mint wen to self
// check:ABORTED
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x100000::SHARE;

    fun main(sender: signer) {
        let max = SHARE::get_max_supply();
        let total_supply = Token::market_cap<SHARE::SHARE>();
        SHARE::mint(&sender, Signer::address_of(&sender), max-total_supply+1);
    }
}