//! account: alice, 0x123, 100 000 000 000
//! account: bob,   0x124, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init mock token
//! sender: owner
script {
    use 0x1::Signer;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        MockToken::initialize(&sender);
        // mint 100 USD
        MockToken::mint(&sender, Signer::address_of(&sender), 100 * 1000 * 1000 * 1000);
    }
}

// init
//! new-transaction
//! sender: owner
script {
    use 0x1::STC::STC;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::TestFarm;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let reward_amount = 10 * 1000 * 1000 * 1000; // 10 USD
        YieldFarming::initialize<TestFarm::STC_WEN, MockToken::USD>(
            &sender,
            reward_amount,
        );
        TestFarm::add_asset<STC>(&sender, 1, 0);
        TestFarm::update_asset<STC>(&sender, 2, true);

        let amount = YieldFarming::query_remaining_reward<TestFarm::STC_WEN, MockToken::USD>();
        assert(amount == reward_amount, 100);
    }
}

// bob can not add asset
// check:ABORTED
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x100000::TestFarm;

    fun main(sender: signer) {
        TestFarm::add_asset<STC>(&sender, 1, 0);
    }
}

// bob can update_pool
//! new-transaction
//! sender: bob
address owner = {{owner}};
script {
    use 0x1::STC::STC;
    use 0x100000::TestFarm;
    use 0x100000::YieldFarmingV1 as YieldFarming;

    fun main(_sender: signer) {
        YieldFarming::update_pool<TestFarm::STC_WEN, STC>();
    }
}

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 500000

// bob can update_pool
//! new-transaction
//! sender: bob
address owner = {{owner}};
script {
    use 0x1::STC::STC;
    use 0x1::Signer;
    use 0x100000::TestFarm;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        YieldFarming::update_pool<TestFarm::STC_WEN, STC>();
        assert(YieldFarming::pending<TestFarm::STC_WEN, USD, STC>(addr) == 0, 200);
        assert(YieldFarming::query_farming_asset<TestFarm::STC_WEN, STC>() == 0, 201);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 600000

// bob deposit
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x1::Signer;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let amount = 10 * 1000 * 1000 * 1000; // 10 STC
        YieldFarming::deposit<STC_WEN, USD, STC>(&sender, amount);
        assert(YieldFarming::query_stake<STC_WEN, STC>(addr) == amount, 300);
        assert(YieldFarming::query_farming_asset<STC_WEN, STC>() == amount, 301);
        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 302);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 700000

// bob pending
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        // old acc reward pre share = 0
        // new acc reward pre share = 100s * 2 * 1e12 / 1e10 = 20000
        // reward = 10USD * (acc reward pre share) / 1e12 = 200
        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 400);

        let balance_before = Account::balance<USD>(addr);

        // deposit 2
        let amount = 10 * 1000 * 1000 * 1000; // 10 STC
        YieldFarming::deposit<STC_WEN, USD, STC>(&sender, amount);

        let balance_after = Account::balance<USD>(addr);

        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 401);
        assert(balance_before + 200 == balance_after, 402);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 800000

// bob harvest
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        // old acc reward pre share = 0
        // new acc reward pre share = 100s * 2 * 1e12 / (2*1e10) = 10000
        // reward = 20USD * (acc reward pre share) / 1e12 = 200
        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 500);

        let deposit_before = YieldFarming::query_stake<STC_WEN, STC>(addr);
        let balance_before = Account::balance<USD>(addr);

        // harvest
        YieldFarming::harvest<STC_WEN, USD, STC>(&sender);

        let balance_after = Account::balance<USD>(addr);
        let deposit_after = YieldFarming::query_stake<STC_WEN, STC>(addr);

        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 501);
        assert(balance_before + 200 == balance_after, 502);
        assert(deposit_before == deposit_after, 503);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 5
//! block-time: 900000

// bob withdraw
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        // old acc reward pre share = 0
        // new acc reward pre share = 100s * 2 * 1e12 / (2*1e10) = 10000
        // reward = 20USD * (acc reward pre share) / 1e12 = 200
        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 600);

        let deposit_before = YieldFarming::query_stake<STC_WEN, STC>(addr);
        let balance_before = Account::balance<USD>(addr);

        // withdraw
        let amount = 10 * 1000 * 1000 * 1000; // 10 USD
        YieldFarming::withdraw<STC_WEN, USD, STC>(&sender, amount);

        let balance_after = Account::balance<USD>(addr);
        let deposit_after = YieldFarming::query_stake<STC_WEN, STC>(addr);

        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 601);
        assert(balance_before + 200 == balance_after, 602);
        assert(deposit_before - amount ==  deposit_after, 603);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 6
//! block-time: 1000000

// bob withdraw all
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::YieldFarmingV1 as YieldFarming;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::MockToken::USD;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 200, 700);

        let deposit_before = YieldFarming::query_stake<STC_WEN, STC>(addr);
        let balance_before = Account::balance<USD>(addr);

        // withdraw all
        YieldFarming::withdraw<STC_WEN, USD, STC>(&sender, deposit_before);

        let balance_after = Account::balance<USD>(addr);
        let deposit_after = YieldFarming::query_stake<STC_WEN, STC>(addr);

        assert(YieldFarming::pending<STC_WEN, USD, STC>(addr) == 0, 701);
        assert(balance_before + 200 == balance_after, 702);
        assert(deposit_after == 0, 703);
    }
}