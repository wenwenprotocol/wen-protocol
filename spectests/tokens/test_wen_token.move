//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr alice

// init wen
//# run --signers WenProtocol
script {
    use WenProtocol::WEN;

    fun main(sender: signer) {
        WEN::initialize(&sender);
    }
}

// accept wen
//# run --signers alice
script {
    use StarcoinFramework::Account;
    use WenProtocol::WEN::WEN;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
    }
}


//# block --author 0x1 --timestamp 1000000

//# run --signers WenProtocol
script {
    use WenProtocol::WEN;

    fun main(sender: signer) {
        // 1000 WEN
        WEN::mint_to(&sender, @alice, 1000 * 1000 * 1000 * 1000);
    }
}


// mint wen to self
//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use WenProtocol::WEN;

    fun main(sender: signer) {
        // 1000 WEN
        WEN::mint_to(&sender, Signer::address_of(&sender), 1000 * 1000 * 1000 * 1000);
    }
}
// check: "Keep(ABORTED { code: 401"


// 24 hours later
//# block --author 0x1 --timestamp 96400000

//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use WenProtocol::WEN;

    fun main(sender: signer) {
        // 15 %
        let total_supply = Token::market_cap<WEN::WEN>();
        let max_amount = total_supply * 15 / 100;
        WEN::mint_to(&sender, Signer::address_of(&sender),  max_amount);
    }
}


// 24 hours later
//# block --author 0x1 --timestamp 9996400000

//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use WenProtocol::WEN;

    fun main(sender: signer) {
        let total_supply = Token::market_cap<WEN::WEN>();
        let max_amount = total_supply * 15 / 100;
        WEN::mint_to(&sender, Signer::address_of(&sender),  max_amount / 2);
    }
}


//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use WenProtocol::WEN;

    fun main(sender: signer) {
        let total_supply = Token::market_cap<WEN::WEN>();
        let max_amount = total_supply * 15 / 100;
        WEN::mint_to(&sender, Signer::address_of(&sender),  max_amount / 3);
    }
}