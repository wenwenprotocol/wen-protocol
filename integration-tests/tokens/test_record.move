//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr alice

//# faucet --addr bob

// every can  register
//# run --signers bob
script {
    use WenProtocol::Record;

    fun main(sender: signer) {
        Record::register(sender);
    }
}


// alice can update
//# run --signers alice
script {
    use StarcoinFramework::PriceOracleScripts;
    use WenProtocol::Record::SSHARE;

    fun main(sender: signer) {
        PriceOracleScripts::init_data_source<SSHARE>(sender, 100);
    }
}


//# run --signers bob
script {
    use StarcoinFramework::PriceOracleScripts;
    use WenProtocol::Record::SSHARE;

    fun main(sender: signer) {
        PriceOracleScripts::init_data_source<SSHARE>(sender, 200);
    }
}


// read
//# run --signers alice
script {
    use WenProtocol::Record;

    fun main(_sender: signer) {
        assert!(Record::get(@bob) == 200, 100);
    }
}


//# run --signers alice
script {
    use StarcoinFramework::PriceOracleScripts;
    use WenProtocol::Record::SSHARE;

    fun main(sender: signer) {
        PriceOracleScripts::update<SSHARE>(sender, 300);
    }
}


// read
//# run --signers alice
script {
    use WenProtocol::Record;

    fun main(_sender: signer) {
        assert!(Record::get(@alice) == 300, 200);
    }
}
