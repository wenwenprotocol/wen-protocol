//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6 --public-keys PublicOracle=0x3517cf661eb9ec48ad86639db66ea463b871b7d10c52bb37461570aef68f8c36 --addresses PublicOracle=0x07fa08a855753f0ff7292fdcbe871216

//# faucet --addr WenProtocol

//# faucet --addr PublicOracle

//# faucet --addr alice --amount 1000000000000

//# faucet --addr bob --amount 1000000000000


// init oracle
//# run --signers PublicOracle
script {
    use WenProtocol::OracleTestHelper;

    fun main(sender: signer) {
        OracleTestHelper::init_data_source(sender, 100 * 1000);// STCUSD = 0.1
    }
}


// init mock token
//# run --signers WenProtocol
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let total_borrow = 1000 * 1000 * 1000 * 1000; // 1000 usd
        MockToken::initialize(&sender, total_borrow);

        LendingPool::initialize<LPTestHelper::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            95000, // liquidation_threshold 95%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            2500, // interest_per_second 2.5%
            total_borrow, // deposit amount
            b"STC_POOL", // poll name
        );

        LendingPool::update_exchange_rate<LPTestHelper::STC_POOL>();
    }
}


//# run --signers alice
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        MockToken::accept_token(&sender);
    }
}

//# block --author 0x1 --timestamp 100000

// bob add collateral
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::MockToken;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        let token_scaling_factor = 1000 * 1000 * 1000;
        // bob add 100 STC as collateral
        LendingPool::add_collateral<LPTestHelper::STC_POOL, STC>(&sender, 100 * token_scaling_factor);
        // bob borrow MockToken::USD and send to alice
        // collaterization_rate= 90%    100STC*90% = 90STC  max usd = 9USD
        LendingPool::borrow<LPTestHelper::STC_POOL, MockToken::USD>(&sender, @alice, 5 * token_scaling_factor);
    }
}


//# block --author 0x1 --timestamp 500000

// update oracle
//# run --signers PublicOracle
script {
    use WenProtocol::OracleTestHelper;
    use WenProtocol::MockToken;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        let price_scaling_factor = 1000000 * 1000000; // 1e12
        let (rate_before, _) = LendingPool::get_exchange_rate<LPTestHelper::STC_POOL>();
        assert!(rate_before == 10 * price_scaling_factor, 101);

        // update  stcusd = 0.01
        OracleTestHelper::update(sender, 1000 * 10);
        let rate = LendingPool::update_exchange_rate<LPTestHelper::STC_POOL>();
        assert!(rate == 100 * price_scaling_factor, 102);

        // bob is solvent
        assert!(!LendingPool::is_solvent<LPTestHelper::STC_POOL, MockToken::USD>(@bob, rate), 501);
    }
}


// alice can liquidate
//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::MockToken;
    use WenProtocol::LPTestHelper;
    use WenProtocol::LendingPoolV2 as LendingPool;

    fun main(sender: signer) {
        let alice = Signer::address_of(&sender);

        // before
        let stc_before = Account::balance<STC>(alice);
        let usd_before = Account::balance<MockToken::USD>(alice);
        let (collateral_before, borrow_before) = LendingPool::position<LPTestHelper::STC_POOL>(@bob);

        // make args
        let users = Vector::empty<address>();
        Vector::push_back<address>(&mut users, @bob);
        // max_part = collateral_before * 1e17/(1e14*105000) = 9 * 1e8
        let max_parts = Vector::empty<u128>();
        Vector::push_back<u128>(&mut max_parts, 9 * 10000 * 10000);

        // request
        LendingPool::liquidate<LPTestHelper::STC_POOL, STC, MockToken::USD>(
            &sender,
            &users,
            &max_parts,
            alice,
        );

        // after
        let (collateral_after, borrow_after) = LendingPool::position<LPTestHelper::STC_POOL>(@bob);
        let stc_after = Account::balance<STC>(alice);
        let usd_after = Account::balance<MockToken::USD>(alice);

        assert!(stc_after > stc_before, 601);
        assert!(usd_after < usd_before, 602);
        assert!(collateral_after < collateral_before, 603);
        assert!(borrow_after < borrow_before, 604);
        assert!(stc_after - stc_before == collateral_before - collateral_after, 605);
    }
}
