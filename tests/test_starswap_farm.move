//! account: alice, 0x123, 100 000 000 000
//! account: bob,   0x124, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init mock token
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::SHARE;
    use 0x100000::WEN;
    use 0x100000::StarSwapFarm;
    use 0x100000::TestFarm::STC_WEN;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let amount = 100 * 1000 * 1000 * 1000;
        SHARE::initialize(&sender);
        WEN::initialize(&sender);
        // mint 100 WEN
        WEN::mint_to(&sender, addr, amount);
        // mint 100 share
        SHARE::mint(&sender, addr, amount * 100);
        StarSwapFarm::initialize<STC_WEN, SHARE::SHARE, STC, WEN::WEN>(
            &sender,
            amount * 100,
            1 * 1000000000, // 1 share/s
            0,
        )
    }
}

//  bob accept wen
//! new-transaction
//! sender: bob
script {
    use 0x1::Account;
    use 0x100000::WEN::WEN;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
    }
}

// transfer to bob
//! new-transaction
//! sender: owner
address bob = {{bob}};
script {
    use 0x1::TransferScripts;
    use 0x100000::WEN::WEN;

    fun main(sender: signer) {
        TransferScripts::peer_to_peer_v2<WEN>(sender, @bob, 100 * 1000 * 1000 * 1000);
    }
}

// init swap pair
//! new-transaction
//! sender: owner
script {
    use 0x1::STC;
    use 0x100000::WEN;
    use 0x100000::TokenSwapScripts;

    fun main(sender: signer) {
        TokenSwapScripts::register_swap_pair<STC::STC, WEN::WEN>(sender);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 500000

// bob add liqudity
//! new-transaction
//! sender: bob
script {
    use 0x1::STC;
    use 0x100000::WEN;
    use 0x100000::TokenSwapScripts;

    fun main(sender: signer) {
        TokenSwapScripts::add_liquidity<STC::STC, WEN::WEN>(
            sender,
            10 * 1000 * 1000 * 1000,    // 10 STC
            10 * 1000 * 1000 * 1000,    // 10 WEN
            0,
            0,
        );
    }
}

// bob deposit
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::StarSwapFarm;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::WEN::WEN;
    use 0x100000::SHARE::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        StarSwapFarm::deposit<STC_WEN, SHARE, STC, WEN>(&sender, 5 * 1000 * 1000 * 1000);
        assert(StarSwapFarm::pending<STC_WEN, SHARE, STC, WEN>(addr) == 0, 100);

        let stake = StarSwapFarm::query_stake<STC_WEN, STC, WEN>(addr);
        assert(stake == 5 * 1000 * 1000 * 1000, 101);

        StarSwapFarm::query_remaining_reward<STC_WEN, SHARE>();
    }
}

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 600000

// bob pending
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::StarSwapFarm;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::WEN::WEN;
    use 0x100000::SHARE::SHARE;

    fun main(sender: signer) {
        // 1 share/s  100 s => 100 share
        let pending = StarSwapFarm::pending<STC_WEN, SHARE, STC, WEN>(Signer::address_of(&sender));
        assert(pending == 100 * 1000 * 1000 * 1000, 200);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 700000

// bob withdraw
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::STC::STC;
    use 0x100000::StarSwapFarm;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::WEN::WEN;
    use 0x100000::SHARE::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let share_before = Account::balance<SHARE>(addr);
        // withdraw
        StarSwapFarm::withdraw<STC_WEN, SHARE, STC, WEN>(&sender, 1 * 1000 * 1000 * 1000);

        let share_after = Account::balance<SHARE>(addr);
        assert(share_before < share_after, 300);
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
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::STC::STC;
    use 0x100000::StarSwapFarm;
    use 0x100000::TestFarm::STC_WEN;
    use 0x100000::WEN::WEN;
    use 0x100000::SHARE::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let share_before = Account::balance<SHARE>(addr);
        let before = StarSwapFarm::query_remaining_reward<STC_WEN, SHARE>();

        // harvest
        StarSwapFarm::harvest<STC_WEN, SHARE, STC, WEN>(&sender);

        let share_after = Account::balance<SHARE>(addr);
        let after = StarSwapFarm::query_remaining_reward<STC_WEN, SHARE>();
        assert(share_before < share_after, 400);
        assert(before > after, 401);

        assert(StarSwapFarm::query_farming_asset<STC_WEN, STC, WEN>() == 4 * 1000 * 1000 * 1000, 402);
    }
}
