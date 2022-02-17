//! account: feeto, 0x123, 100 000 000 000
//! account: bob,   0x124, 9000 000 000 000
//! account: alice,  0x125, 100 000 000 000
//! account: oracle, 0x07fa08a855753f0ff7292fdcbe871216, 100 000 000 000
//! account: owner, 0x100000,  20000 000 000 000

// init token
//! sender: owner
address feeto = {{feeto}};
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::SHARE;
    use 0x100000::WEN;
    use 0x100000::TokenSwapRouter;
    use 0x100000::LendingPool;
    use 0x100000::STCLendingPoolV1::STC_POOL;
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let scale = 1000 * 1000 * 1000;
        SHARE::initialize(&sender);
        WEN::initialize(&sender);
        // mint 5000 WEN
        WEN::mint_to(&sender, addr, 5000 * scale);
        // mint 500000 share
        SHARE::mint(&sender, addr, 500000 * scale);

        // stc-wen  5000 : 500
        TokenSwapRouter::register_swap_pair<STC, WEN::WEN>(&sender);
        TokenSwapRouter::add_liquidity<STC, WEN::WEN>(&sender, 5000 * scale, 500 * scale, 0, 0);

        // stc-share  5000 : 500000
        TokenSwapRouter::register_swap_pair<STC, SHARE::SHARE>(&sender);
        TokenSwapRouter::add_liquidity<STC, SHARE::SHARE>(&sender, 5000 * scale, 500000 * scale, 0, 0);

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

// set permission
//! new-transaction
//! sender: owner
address feeto = {{feeto}};
script {
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        Withdrawer::add_verifier(sender, @feeto);
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
//! block-number: 1
//! block-time: 100000

// bob deposit and borrow
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x100000::LendingPool;
    use 0x100000::WEN::WEN;
    use 0x100000::STCLendingPoolV1::STC_POOL;

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

        assert(before == 0, 100);
        assert(after == 500 * scale, 101);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 600000

// alice can not withdraw fee
// check: ABORTED
//! new-transaction
//! sender: alice
script {
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        assert(Withdrawer::balance() == 0, 200);
        Withdrawer::withdraw_fee(sender);
    }
}

// feeto can withdraw fee
//! new-transaction
//! sender: feeto
script {
    use 0x1::Account;
    use 0x100000::WEN::WEN;
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
        assert(Withdrawer::balance() == 0, 300);
        Withdrawer::withdraw_fee(sender);
        assert(Withdrawer::balance() > 0, 301);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 700000

//! new-transaction
//! sender: owner
script {
    use 0x100000::SSHARE;

    fun main(sender: signer) {
        SSHARE::initialize(sender);
        assert(SSHARE::balance() == 0, 400);
    }
}

// alice can not swap
// check: ABORTED
//! new-transaction
//! sender: alice
script {
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        Withdrawer::swap_wen_for_share(sender);
    }
}
// check: ABORTED


// feeto can swap
//! new-transaction
//! sender: feeto
script {
    use 0x100000::SSHARE;
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        assert(SSHARE::balance() == 0, 500);
        Withdrawer::swap_wen_for_share(sender);
        assert(Withdrawer::balance() == 0, 501);
        assert(SSHARE::balance() > 0, 502);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 1000000

// feeto can withdraw and swap
//! new-transaction
//! sender: feeto
script {
    use 0x100000::SSHARE;
    use 0x100000::WithdrawerV1 as Withdrawer;

    fun main(sender: signer) {
        let s_before = SSHARE::balance();
        let before = Withdrawer::balance();

        Withdrawer::withdraw_and_swap(sender);

        let s_after = SSHARE::balance();
        let after = Withdrawer::balance();
        assert(before == after, 600);
        assert(s_before < s_after, 601);
    }
}
