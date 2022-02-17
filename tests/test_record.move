//! account: alice, 0x123, 100 000 000 000
//! account: bob,   0x124, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// every can  register
//! sender: bob
script {
    use 0x100000::Record;

    fun main(sender: signer) {
        Record::register(sender);
    }
}

// alice can update
//! new-transaction
//! sender: alice
script {
    use 0x1::PriceOracleScripts;
    use 0x100000::Record::SSHARE;

    fun main(sender: signer) {
        PriceOracleScripts::init_data_source<SSHARE>(sender, 100);
    }
}

//! new-transaction
//! sender: bob
script {
    use 0x1::PriceOracleScripts;
    use 0x100000::Record::SSHARE;

    fun main(sender: signer) {
        PriceOracleScripts::init_data_source<SSHARE>(sender, 200);
    }
}


// read
//! new-transaction
//! sender: alice
address bob = {{bob}};
script {
    use 0x100000::Record;

    fun main(_sender: signer) {
        assert(Record::get(@bob) == 200, 100);
    }
}

//! new-transaction
//! sender: alice
script {
    use 0x1::PriceOracleScripts;
    use 0x100000::Record::SSHARE;

    fun main(sender: signer) {
        PriceOracleScripts::update<SSHARE>(sender, 300);
    }
}

// read
//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x100000::Record;

    fun main(_sender: signer) {
        assert(Record::get(@alice) == 300, 200);
    }
}
