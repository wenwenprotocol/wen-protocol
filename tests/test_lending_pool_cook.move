//! account: alice, 0x123, 1000 000 000 000
//! account: bob,   0x124, 1000 000 000 000
//! account: oracle, 0x07fa08a855753f0ff7292fdcbe871216, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init mock token
//! sender: owner
script {
    use 0x1::Signer;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        MockToken::initialize(&sender);
        MockToken::mint(&sender, Signer::address_of(&sender), 1000* 1000 * 1000 * 1000);
    }
}

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

// register
//! new-transaction
//! sender: owner
script {
    use 0x1::STC::STC;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        LendingPool::initialize<TestLP::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            2500, // interest_per_second 2.5%
            1000 * 1000 * 1000 * 1000, // deposit amount
            b"STC_POOL", // poll name
        );
    }
}

// init oracle
//! new-transaction
//! sender: oracle
script {
    use 0x1::STCUSDOracle;
    use 0x1::PriceOracle;

    fun main(sender: signer) {
        PriceOracle::init_data_source<STCUSDOracle::STCUSD>(&sender, 0);
        PriceOracle::update<STCUSDOracle::STCUSD>(&sender, 1000 * 100); // STCUSD = 0.1
    }
}

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 300000

// every can update exchange
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
        let rate = LendingPool::update_exchange_rate<TestLP::STC_POOL>();
        // stc_price = 1000 * 100 = 1e5 price_precision = 1000 * 1000 = 1e6
        // exhcang_rate_PRECISION = 1e12  =>  rate = (price_precision * 1e12) / stc_price = 1e13 => 10STC = 1USD
        assert(rate == 100000 * 100000 * 1000, 201);
        // bob add 100 STC as collateral
        LendingPool::add_collateral<TestLP::STC_POOL, STC>(&sender, 100 * token_scaling_factor);
        // bob borrow MockToken::USD and send to alice
        // collaterization_rate= 90%    100STC*90% = 90STC  max usd = 9USD
        LendingPool::borrow<TestLP::STC_POOL, MockToken::USD>(&sender, @alice, 5 * token_scaling_factor);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 500000

//! new-transaction
//! sender: alice
script {
    use 0x100000::MockToken;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(_sender: signer) {
        let (_, fees_earned_before, _) = LendingPool::fee_info<TestLP::STC_POOL>();
        LendingPool::accrue<TestLP::STC_POOL, MockToken::USD>();
        let (_, fees_earned_after, _) = LendingPool::fee_info<TestLP::STC_POOL>();
        assert(fees_earned_before < fees_earned_after, 301);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 600000

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::STC::STC;
    use 0x1::Vector;
    use 0x1::Account;

    use 0x100000::MockToken;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        let token_scaling_factor = 1000 * 1000 * 1000;
        let actions = Vector::empty<u8>();
        // ACTION_ADD_COLLATERAL
        Vector::push_back<u8>(&mut actions, 1);
        // ACTION_BORROW
        Vector::push_back<u8>(&mut actions, 3);
        // ACTION_REPAY
        Vector::push_back<u8>(&mut actions, 4);
        // ACTION_REMOVE_COLLATERAL
        Vector::push_back<u8>(&mut actions, 2);

        let before = Account::balance<MockToken::USD>(@alice);

        LendingPool::cook<TestLP::STC_POOL, STC, MockToken::USD>(
            &sender,
            &actions,
            100 * token_scaling_factor,         // collateral amount
            1 * token_scaling_factor, @alice, // remove collateral
            1 * token_scaling_factor, @alice,   // borrow amount
            1 * token_scaling_factor, @alice,   // repay amount
        );

        let after = Account::balance<MockToken::USD>(@alice);

        // because borrow fee
        assert(after < before, 401);
    }
}
