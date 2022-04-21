//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr bob

// init mock token
//# run --signers WenProtocol
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        // mint 100 USD
        MockToken::initialize(&sender, 100 * 1000 * 1000 * 1000);
    }
}

// init
//# run --signers WenProtocol
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::FarmTestHelper;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let reward_amount = 10 * 1000 * 1000 * 1000; // 10 USD
        YieldFarming::initialize<FarmTestHelper::STC_WEN, USD>(
            &sender,
            reward_amount,
        );
        FarmTestHelper::add_asset<STC>(&sender, 1, 0);
        FarmTestHelper::update_asset<STC>(&sender, 2, true);

        let amount = YieldFarming::query_remaining_reward<FarmTestHelper::STC_WEN, USD>();
        assert!(amount == reward_amount, 100);
    }
}


// bob can not add asset
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::FarmTestHelper;

    fun main(sender: signer) {
        FarmTestHelper::add_asset<STC>(&sender, 1, 0);
    }
}
// check:ABORTED


// bob can update_pool
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::FarmTestHelper;
    use WenProtocol::YieldFarmingV1 as YieldFarming;

    fun main(_sender: signer) {
        YieldFarming::update_pool<FarmTestHelper::STC_WEN, STC>();
    }
}

//# block --author 0x1 --timestamp 500000

// bob can update_pool
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use WenProtocol::FarmTestHelper;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        YieldFarming::update_pool<FarmTestHelper::STC_WEN, STC>();
        assert!(YieldFarming::pending<FarmTestHelper::STC_WEN, USD, STC>(addr) == 0, 200);
        assert!(YieldFarming::query_farming_asset<FarmTestHelper::STC_WEN, STC>() == 0, 201);
    }
}

//# block --author 0x1 --timestamp 600000

// bob deposit
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let amount = 10 * 1000 * 1000 * 1000; // 10 STC
        YieldFarming::deposit<STC_WEN, USD, STC>(&sender, amount);
        assert!(YieldFarming::query_stake<STC_WEN, STC>(addr) == amount, 300);
        assert!(YieldFarming::query_farming_asset<STC_WEN, STC>() == amount, 301);
        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 302);
    }
}


//# block --author 0x1 --timestamp 700000

// bob pending
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        // old acc reward pre share = 0
        // new acc reward pre share = 100s * 2 * 1e12 / 1e10 = 20000
        // reward = 10USD * (acc reward pre share) / 1e12 = 200
        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 400);

        let balance_before = Account::balance<USD>(addr);

        // deposit 2
        let amount = 10 * 1000 * 1000 * 1000; // 10 STC
        YieldFarming::deposit<STC_WEN, USD, STC>(&sender, amount);

        let balance_after = Account::balance<USD>(addr);

        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 401);
        assert!(balance_before + 200 == balance_after, 402);
    }
}


//# block --author 0x1 --timestamp 800000

// bob harvest
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        // old acc reward pre share = 0
        // new acc reward pre share = 100s * 2 * 1e12 / (2*1e10) = 10000
        // reward = 20USD * (acc reward pre share) / 1e12 = 200
        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 500);

        let deposit_before = YieldFarming::query_stake<STC_WEN, STC>(addr);
        let balance_before = Account::balance<USD>(addr);

        // harvest
        YieldFarming::harvest<STC_WEN, USD, STC>(&sender);

        let balance_after = Account::balance<USD>(addr);
        let deposit_after = YieldFarming::query_stake<STC_WEN, STC>(addr);

        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 501);
        assert!(balance_before + 200 == balance_after, 502);
        assert!(deposit_before == deposit_after, 503);
    }
}

//# block --author 0x1 --timestamp 900000

// bob withdraw
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        // old acc reward pre share = 0
        // new acc reward pre share = 100s * 2 * 1e12 / (2*1e10) = 10000
        // reward = 20USD * (acc reward pre share) / 1e12 = 200
        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 600);

        let deposit_before = YieldFarming::query_stake<STC_WEN, STC>(addr);
        let balance_before = Account::balance<USD>(addr);

        // withdraw
        let amount = 10 * 1000 * 1000 * 1000; // 10 USD
        YieldFarming::withdraw<STC_WEN, USD, STC>(&sender, amount);

        let balance_after = Account::balance<USD>(addr);
        let deposit_after = YieldFarming::query_stake<STC_WEN, STC>(addr);

        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 601);
        assert!(balance_before + 200 == balance_after, 602);
        assert!(deposit_before - amount ==  deposit_after, 603);
    }
}


//# block --author 0x1 --timestamp 1000000

// bob withdraw all
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::YieldFarmingV1 as YieldFarming;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 700);

        let deposit_before = YieldFarming::query_stake<STC_WEN, STC>(addr);
        let balance_before = Account::balance<USD>(addr);

        // withdraw all
        YieldFarming::withdraw<STC_WEN, USD, STC>(&sender, deposit_before);

        let balance_after = Account::balance<USD>(addr);
        let deposit_after = YieldFarming::query_stake<STC_WEN, STC>(addr);

        assert!(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 701);
        assert!(balance_before + 200 == balance_after, 702);
        assert!(deposit_after == 0, 703);
    }
}
