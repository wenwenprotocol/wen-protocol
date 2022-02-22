//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6 PublicOracle=0x3517cf661eb9ec48ad86639db66ea463b871b7d10c52bb37461570aef68f8c36 --addresses PublicOracle=0x07fa08a855753f0ff7292fdcbe871216

//# faucet --addr WenProtocol

//# faucet --addr PublicOracle

//# faucet --addr alice --amount 1000000000000

//# faucet --addr bob --amount 1000000000000


// init mock token
//# run --signers WenProtocol
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        MockToken::initialize(&sender, 1000 * 1000 * 1000 * 1000);
    }
}


//# run --signers alice
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        MockToken::accept_token(&sender);
    }
}


// init oracle
//# run --signers PublicOracle
script {
    use WenProtocol::OracleTestHelper;

    fun main(sender: signer) {
        OracleTestHelper::init_data_source(sender, 100 * 1000);// STCUSD = 0.1
    }
}


//# block --author 0x1 --timestamp 100000

// register
//# run --signers WenProtocol
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        LendingPool::initialize<LPTestHelper::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            95000, // liquidation_threshold 95%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            2500, // interest_per_second 2.5%
            1000 * 1000 * 1000 * 1000, // deposit amount
            b"STC_POOL", // poll name
        );
    }
}


//# block --author 0x1 --timestamp 300000

// every can update exchange
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::MockToken;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        let token_scaling_factor = 1000 * 1000 * 1000;
        let rate = LendingPool::update_exchange_rate<LPTestHelper::STC_POOL>();
        // stc_price = 1000 * 100 = 1e5 price_precision = 1000 * 1000 = 1e6
        // exhcang_rate_PRECISION = 1e12  =>  rate = (price_precision * 1e12) / stc_price = 1e13 => 10STC = 1USD
        assert!(rate == 100000 * 100000 * 1000, 201);
        // bob add 100 STC as collateral
        LendingPool::add_collateral<LPTestHelper::STC_POOL, STC>(&sender, 100 * token_scaling_factor);
        // bob borrow MockToken::USD and send to alice
        // collaterization_rate= 90%    100STC*90% = 90STC  max usd = 9USD
        LendingPool::borrow<LPTestHelper::STC_POOL, MockToken::USD>(&sender, @alice, 5 * token_scaling_factor);
    }
}


//# block --author 0x1 --timestamp 500000

//# run --signers alice
script {
    use WenProtocol::MockToken;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;

    fun main(_sender: signer) {
        let (_, fees_earned_before, _) = LendingPool::fee_info<LPTestHelper::STC_POOL>();
        LendingPool::accrue<LPTestHelper::STC_POOL, MockToken::USD>();
        let (_, fees_earned_after, _) = LendingPool::fee_info<LPTestHelper::STC_POOL>();
        assert!(fees_earned_before < fees_earned_after, 301);
    }
}


//# block --author 0x1 --timestamp 600000

//# run --signers alice
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Account;

    use WenProtocol::MockToken;
    use WenProtocol::LendingPoolV2 as LendingPool;
    use WenProtocol::LPTestHelper;

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

        LendingPool::cook<LPTestHelper::STC_POOL, STC, MockToken::USD>(
            &sender,
            &actions,
            100 * token_scaling_factor,         // collateral amount
            1 * token_scaling_factor, @alice, // remove collateral
            1 * token_scaling_factor, @alice,   // borrow amount
            1 * token_scaling_factor, @alice,   // repay amount
        );

        let after = Account::balance<MockToken::USD>(@alice);

        // because borrow fee
        assert!(after < before, 401);
    }
}
