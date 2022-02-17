//! account: alice, 0x123, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init share / sshare
//! sender: owner
script {
    use 0x100000::WEN;

    fun main(sender: signer) {
        WEN::initialize(&sender);
    }
}

// accept wen
//! new-transaction
//! sender: alice
script {
    use 0x1::Account;
    use 0x100000::WEN::WEN;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 100000

// mint wen to alice
//! new-transaction
//! sender: owner
address alice = {{alice}};
script {
    use 0x100000::WEN;

    fun main(sender: signer) {
        // 1000 WEN
        WEN::mint_to(&sender, @alice, 1000 * 1000 * 1000 * 1000);
    }
}

// mint wen to self
// check:ABORTED
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x100000::WEN;

    fun main(sender: signer) {
        // 1000 WEN
        WEN::mint_to(&sender, Signer::address_of(&sender), 1000 * 1000 * 1000 * 1000);
    }
}

// 24 hours later
//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 96400000

// mint wen to self
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x100000::WEN;

    fun main(sender: signer) {
        // 15 %
        let total_supply = Token::market_cap<WEN::WEN>();
        let max_amount = total_supply * 15 / 100;
        WEN::mint_to(&sender, Signer::address_of(&sender),  max_amount);
    }
}

// 24 hours later
//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 9996400000

// mint wen to self
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x100000::WEN;

    fun main(sender: signer) {
        let total_supply = Token::market_cap<WEN::WEN>();
        let max_amount = total_supply * 15 / 100;
        WEN::mint_to(&sender, Signer::address_of(&sender),  max_amount / 2);
    }
}

// mint wen to self
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x100000::WEN;

    fun main(sender: signer) {
        let total_supply = Token::market_cap<WEN::WEN>();
        let max_amount = total_supply * 15 / 100;
        WEN::mint_to(&sender, Signer::address_of(&sender),  max_amount / 3);
    }
}