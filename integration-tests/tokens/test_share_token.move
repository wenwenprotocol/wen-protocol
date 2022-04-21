//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr alice

// init share
//# run --signers WenProtocol
script {
    use WenProtocol::SHARE;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
    }
}


// alice accept SHARE
//# run --signers alice
script {
    use StarcoinFramework::Account;
    use WenProtocol::SHARE::SHARE;

    fun main(sender: signer) {
        Account::do_accept_token<SHARE>(&sender);
    }
}

// mint wen to alice
//# run --signers WenProtocol
script {
    use WenProtocol::SHARE;

    fun main(sender: signer) {
        // 1000 SHARE
        SHARE::mint(&sender, @alice, 1000 * 1000 * 1000 * 1000);
    }
}

// mint wen to self
//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use WenProtocol::SHARE;

    fun main(sender: signer) {
        let max = SHARE::get_max_supply();
        let total_supply = Token::market_cap<SHARE::SHARE>();
        SHARE::mint(&sender, Signer::address_of(&sender), max-total_supply+1);
    }
}
// check: "Keep(ABORTED { code: 100"