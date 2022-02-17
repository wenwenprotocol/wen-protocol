//! account: alice, 0x123, 100 000 000 000
//! account: bob,   0x124, 100 000 000 000
//! account: oracle, 0x07fa08a855753f0ff7292fdcbe871216, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// bob can not register
// check:ABORTED
//! sender: bob
script {
    use 0x100000::PoolOracle;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        PoolOracle::register<TestLP::STC_POOL>(&sender, b"STC_POOL");
    }
}

// owner can register
//! new-transaction
//! sender: owner
script {
    use 0x100000::PoolOracle;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        PoolOracle::register<TestLP::STC_POOL>(&sender, b"STC_POOL");
    }
}

//! new-transaction
//! sender: bob
script {
    use 0x100000::PoolOracle;
    use 0x100000::TestLP;

    fun main(_sender: signer) {
        let (p, s, _) = PoolOracle::get<TestLP::STC_POOL>();
        assert(p == 0, 101);
        assert(s == 0, 102);
    }
}


// init price
//! new-transaction
//! sender: oracle
script {
    use 0x1::STCUSDOracle;
    use 0x1::PriceOracle;
    use 0x100000::StcPoolOracle;

    fun main(sender: signer) {
        PriceOracle::init_data_source<STCUSDOracle::STCUSD>(&sender, 0);
        PriceOracle::update<STCUSDOracle::STCUSD>(&sender, 1000 * 10000);

        // get
        let (price, scaling_factor) = StcPoolOracle::get();
        assert(price == 1000 * 10000, 101);
        assert(scaling_factor == 1000 * 1000, 102);
    }
}


// everybody can update
//! new-transaction
//! sender: alice
script {
    use 0x100000::PoolOracle;
    use 0x100000::TestLP;

    fun main(_sender: signer) {
        PoolOracle::update<TestLP::STC_POOL>();

        let (p, s, _) = PoolOracle::get<TestLP::STC_POOL>();

        // stc price = 1000 * 10000  => 1STC=10USD
        // p = 0.1 * s
        assert(p == 1000000 * 100000, 301);
        assert(s == 1000000 * 1000000, 302);
    }
}
