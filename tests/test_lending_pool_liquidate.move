//! account: alice, 0x123, 1000 000 000 000
//! account: bob,   0x124, 1000 000 000 000
//! account: oracle, 0x07fa08a855753f0ff7292fdcbe871216, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init oracle
//! sender: oracle
script {
    use 0x1::STCUSDOracle;
    use 0x1::PriceOracle;

    fun main(sender: signer) {
        // update stc oracle STCUSD = 0.1
        PriceOracle::init_data_source<STCUSDOracle::STCUSD>(&sender, 0);
        PriceOracle::update<STCUSDOracle::STCUSD>(&sender, 1000 * 100);
    }
}

// init mock token
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let total_borrow = 1000 * 1000 * 1000 * 1000; // 1000 usd
        MockToken::initialize(&sender);
        MockToken::mint(&sender, Signer::address_of(&sender), total_borrow);

        LendingPool::initialize<TestLP::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            2500, // interest_per_second 2.5%
            total_borrow, // deposit amount
            b"STC_POOL", // poll name
        );

        LendingPool::update_exchange_rate<TestLP::STC_POOL>();
    }
}

// alice accept usd
//! new-transaction
//! sender: alice
script {
    use 0x1::Account;
    use 0x100000::MockToken;
    fun main(sender: signer) {
        Account::do_accept_token<MockToken::USD>(&sender);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 100000

// bob add collateral
//! new-transaction
//! sender: bob
address alice = {{alice}};
script {
    use 0x1::STC::STC;
    use 0x100000::MockToken;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        let token_scaling_factor = 1000 * 1000 * 1000;
        // bob add 100 STC as collateral
        LendingPool::add_collateral<TestLP::STC_POOL, STC>(&sender, 100 * token_scaling_factor);
        // bob borrow MockToken::USD and send to alice
        // collaterization_rate= 90%    100STC*90% = 90STC  max usd = 9USD
        LendingPool::borrow<TestLP::STC_POOL, MockToken::USD>(&sender, @alice, 5 * token_scaling_factor);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 500000

// update oracle
//! new-transaction
//! sender: oracle
address bob = {{bob}};
script {
    use 0x1::STCUSDOracle;
    use 0x1::PriceOracle;
    use 0x100000::MockToken;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        let price_scaling_factor = 1000000 * 1000000; // 1e12
        let (rate_before, _) = LendingPool::get_exchange_rate<TestLP::STC_POOL>();
        assert(rate_before == 10 * price_scaling_factor, 101);

        // update  stcusd = 0.01
        PriceOracle::update<STCUSDOracle::STCUSD>(&sender, 1000 * 10);
        let rate = LendingPool::update_exchange_rate<TestLP::STC_POOL>();
        assert(rate == 100 * price_scaling_factor, 102);

        // bob is solvent
        assert(!LendingPool::is_solvent<TestLP::STC_POOL, MockToken::USD>(@bob, rate), 501);
    }
}

// alice can liquidate
//! new-transaction
//! sender: alice
address bob = {{bob}};
script {
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::MockToken;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        let alice = Signer::address_of(&sender);

        // before
        let stc_before = Account::balance<STC>(alice);
        let usd_before = Account::balance<MockToken::USD>(alice);
        let (collateral_before, borrow_before) = LendingPool::position<TestLP::STC_POOL>(@bob);

        // make args
        let users = Vector::empty<address>();
        Vector::push_back<address>(&mut users, @bob);
        // max_part = collateral_before * 1e17/(1e14*105000) = 9 * 1e8
        let max_parts = Vector::empty<u128>();
        Vector::push_back<u128>(&mut max_parts, 9 * 10000 * 10000);

        // request
        LendingPool::liquidate<TestLP::STC_POOL, STC, MockToken::USD>(
            &sender,
            &users,
            &max_parts,
            alice,
        );

        // after
        let (collateral_after, borrow_after) = LendingPool::position<TestLP::STC_POOL>(@bob);
        let stc_after = Account::balance<STC>(alice);
        let usd_after = Account::balance<MockToken::USD>(alice);

        assert(stc_after > stc_before, 601);
        assert(usd_after < usd_before, 602);
        assert(collateral_after < collateral_before, 603);
        assert(borrow_after < borrow_before, 604);
        assert(stc_after - stc_before == collateral_before - collateral_after, 605);
    }
}
