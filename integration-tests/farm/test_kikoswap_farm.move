//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6 --public-keys KikoSwap=0xf3a4785b667500bbb2181b2709cb384ccfc82b6cdff9cb2446dec57a02e85636

//# faucet --addr WenProtocol

//# faucet --addr KikoSwap

//# faucet --addr bob

//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use WenProtocol::KikoSwapFarm;
    use WenProtocol::FarmTestHelper::STC_WEN;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let amount = 100 * 1000 * 1000 * 1000;
        SHARE::initialize(&sender);
        WEN::initialize(&sender);
        // mint 100 WEN
        WEN::mint_to(&sender, addr, amount);
        // mint 100 share
        SHARE::mint(&sender, addr, amount * 100);
        KikoSwapFarm::initialize<STC_WEN, SHARE::SHARE, STC, WEN::WEN>(
            &sender,
            amount * 100,
            1 * 1000000000, // 1 share/s
            0,
        )
    }
}

//  bob accept wen
//# run --signers bob
script {
    use StarcoinFramework::Account;
    use WenProtocol::WEN::WEN;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
    }
}

// transfer to bob
//# run --signers WenProtocol
script {
    use StarcoinFramework::TransferScripts;
    use WenProtocol::WEN::WEN;

    fun main(sender: signer) {
        TransferScripts::peer_to_peer_v2<WEN>(sender, @bob, 100 * 1000 * 1000 * 1000);
    }
}


// init swap pair
//# run --signers KikoSwap
script {
    use StarcoinFramework::STC;
    use WenProtocol::WEN;
    use KikoSwap::SwapScripts;
    use KikoSwap::SwapConfig;

    fun main(sender: signer) {
        SwapConfig::initialize(&sender, 30, 5, 0, 0, 0, 0, 0);
        SwapScripts::create_pair<STC::STC, WEN::WEN>(sender);
    }
}

//# block --author 0x1 --timestamp 500000

// bob add liqudity
//# run --signers bob
script {
    use StarcoinFramework::STC;
    use WenProtocol::WEN;
    use KikoSwap::SwapScripts;

    fun main(sender: signer) {
        SwapScripts::add_liquidity<STC::STC, WEN::WEN>(
            sender,
            10 * 1000 * 1000 * 1000,    // 10 STC
            10 * 1000 * 1000 * 1000,    // 10 WEN
            0,
            0,
        );
    }
}


// bob deposit
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::KikoSwapFarm;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::WEN::WEN;
    use WenProtocol::SHARE::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        KikoSwapFarm::deposit<STC_WEN, SHARE, STC, WEN>(&sender, 5 * 1000 * 1000 * 1000);
        assert!(KikoSwapFarm::pending<STC_WEN, SHARE, STC, WEN>(addr) == 0, 100);

        let stake = KikoSwapFarm::query_stake<STC_WEN, STC, WEN>(addr);
        assert!(stake == 5 * 1000 * 1000 * 1000, 101);

        KikoSwapFarm::query_remaining_reward<STC_WEN, SHARE>();
    }
}


//# block --author 0x1 --timestamp 600000

// bob pending
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::KikoSwapFarm;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::WEN::WEN;
    use WenProtocol::SHARE::SHARE;

    fun main(sender: signer) {
        // 1 share/s  100 s => 100 share
        let pending = KikoSwapFarm::pending<STC_WEN, SHARE, STC, WEN>(Signer::address_of(&sender));
        assert!(pending == 100 * 1000 * 1000 * 1000, 200);
    }
}


//# block --author 0x1 --timestamp 700000

// bob withdraw
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::STC::STC;
    use WenProtocol::KikoSwapFarm;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::WEN::WEN;
    use WenProtocol::SHARE::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let share_before = Account::balance<SHARE>(addr);
        // withdraw
        KikoSwapFarm::withdraw<STC_WEN, SHARE, STC, WEN>(&sender, 1 * 1000 * 1000 * 1000);

        let share_after = Account::balance<SHARE>(addr);
        assert!(share_before < share_after, 300);
    }
}

//# block --author 0x1 --timestamp 800000

// bob harvest
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::STC::STC;
    use WenProtocol::KikoSwapFarm;
    use WenProtocol::FarmTestHelper::STC_WEN;
    use WenProtocol::WEN::WEN;
    use WenProtocol::SHARE::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let share_before = Account::balance<SHARE>(addr);
        let before = KikoSwapFarm::query_remaining_reward<STC_WEN, SHARE>();

        // harvest
        KikoSwapFarm::harvest<STC_WEN, SHARE, STC, WEN>(&sender);

        let share_after = Account::balance<SHARE>(addr);
        let after = KikoSwapFarm::query_remaining_reward<STC_WEN, SHARE>();
        assert!(share_before < share_after, 400);
        assert!(before > after, 401);

        assert!(KikoSwapFarm::query_farming_asset<STC_WEN, STC, WEN>() == 4 * 1000 * 1000 * 1000, 402);
    }
}
