//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6 StarSwap=0x9e24b6eb5ee291fe4977623a246931bf0675f402ad824a617f4ab8b8c48c934a PublicOracle=0x3517cf661eb9ec48ad86639db66ea463b871b7d10c52bb37461570aef68f8c36 --addresses PublicOracle=0x07fa08a855753f0ff7292fdcbe871216

//# faucet --addr WenProtocol --amount 20000000000000

//# faucet --addr StarSwap

//# faucet --addr PublicOracle

//# faucet --addr alice

//# faucet --addr bob --amount 9000000000000

//# faucet --addr feeto


//# run --signers PublicOracle
script {
    use WenProtocol::OracleTestHelper;

    fun main(sender: signer) {
        // stc = 0.1usd
        OracleTestHelper::init_data_source(sender, 100 * 1000);
    }
}


// init token and lendingpool
//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use WenProtocol::LendingPool;
    use WenProtocol::STCLendingPoolV1::STC_POOL;
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let scale = 1000 * 1000 * 1000;
        SHARE::initialize(&sender);
        WEN::initialize(&sender);
        // mint 5000 WEN
        WEN::mint_to(&sender, addr, 5000 * scale);
        // mint 500000 share
        SHARE::mint(&sender, addr, 500000 * scale);

        // init stc Lendingpool
        LendingPool::initialize<STC_POOL, STC, WEN::WEN>(
            &sender,
            90000, // collaterization_rate 90%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            50000, // interest_per_second 50%
            1000 * scale, // deposit 1000 WEN
            b"STC_POOL", // poll name
        );
        // set fee to
        LendingPool::set_fee_to<STC_POOL>(&sender, @feeto);

        // init withdrawer
        Withdrawer::initialize(sender, 0);
    }
}


//# run --signers StarSwap
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use StarSwap::TokenSwapRouter;
    fun main(sender: signer) {
        TokenSwapRouter::register_swap_pair<STC, WEN::WEN>(&sender);
        TokenSwapRouter::register_swap_pair<STC, SHARE::SHARE>(&sender);
    }
}


// add lp
//# run --signers WenProtocol
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use StarSwap::TokenSwapRouter;
    fun main(sender: signer) {
        let scale = 1000 * 1000 * 1000;

        // stc-wen  5000 : 500
        TokenSwapRouter::add_liquidity<STC, WEN::WEN>(&sender, 5000 * scale, 500 * scale, 0, 0);

        // stc-share  5000 : 500000
        TokenSwapRouter::add_liquidity<STC, SHARE::SHARE>(&sender, 5000 * scale, 500000 * scale, 0, 0);
    }
}


// set permission
//# run --signers WenProtocol
script {
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        Withdrawer::add_verifier(sender, @feeto);
    }
}


//# block --author 0x1 --timestamp 100000

// bob deposit and borrow
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Account;
    use WenProtocol::LendingPool;
    use WenProtocol::WEN::WEN;
    use WenProtocol::STCLendingPoolV1::STC_POOL;

    fun main(sender: signer) {

        let actions = Vector::empty<u8>();
        // ACTION_ADD_COLLATERAL
        Vector::push_back<u8>(&mut actions, 1);
        // ACTION_BORROW
        Vector::push_back<u8>(&mut actions, 3);

        let addr = Signer::address_of(&sender);
        let scale = 1000 * 1000 * 1000;

        let before = Account::balance<WEN>(addr);

        LendingPool::cook<STC_POOL, STC, WEN>(
            &sender,
            &actions,
            8000 * scale,           // collateral amount
            0, addr,                // remove collateral
            500 * scale, addr,   // borrow amount
            0, addr,                // repay amount
        );

        let after = Account::balance<WEN>(addr);

        assert!(before == 0, 100);
        assert!(after == 500 * scale, 101);
    }
}


//# block --author 0x1 --timestamp 600000

// alice can not withdraw fee
//# run --signers alice
script {
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        assert!(Withdrawer::balance() == 0, 200);
        Withdrawer::withdraw_fee(sender);
    }
}
// check: ABORTED


// feeto can withdraw fee
//# run --signers feeto
script {
    use StarcoinFramework::Account;
    use WenProtocol::WEN::WEN;
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
        assert!(Withdrawer::balance() == 0, 300);
        Withdrawer::withdraw_fee(sender);
        assert!(Withdrawer::balance() > 0, 301);
    }
}


//# block --author 0x1 --timestamp 700000

//# run --signers WenProtocol
script {
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        SSHARE::initialize(sender);
        assert!(SSHARE::balance() == 0, 400);
    }
}


// alice can not swap
//# run --signers alice
script {
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        Withdrawer::swap_wen_for_share(sender);
    }
}
// check: ABORTED


// feeto can swap
//# run --signers feeto
script {
    use WenProtocol::SSHARE;
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        assert!(SSHARE::balance() == 0, 500);
        Withdrawer::swap_wen_for_share(sender);
        assert!(Withdrawer::balance() == 0, 501);
        assert!(SSHARE::balance() > 0, 502);
    }
}


//# block --author 0x1 --timestamp 1000000

// feeto can withdraw and swap
//# run --signers feeto
script {
    use WenProtocol::SSHARE;
    use WenProtocol::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        let s_before = SSHARE::balance();
        let before = Withdrawer::balance();

        Withdrawer::withdraw_and_swap(sender);

        let s_after = SSHARE::balance();
        let after = Withdrawer::balance();
        assert!(before == after, 600);
        assert!(s_before < s_after, 601);
    }
}
