//! account: feeto, 0x123, 100 000 000 000
//! account: bob,   0x124, 9000 000 000 000
//! account: alice,  0x125, 100 000 000 000
//! account: oracle, 0x07fa08a855753f0ff7292fdcbe871216, 100 000 000 000
//! account: owner, 0x100000,  20000 000 000 000
//! account: swaper, 0x400000,  20000 000 000 000

// init token and lendingpool
//! sender: owner
script {
    use 0x100000::SHARE;
    use 0x100000::WEN;
    use 0x100000::STCLendingPoolV2;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
        WEN::initialize(&sender);
        // init stc Lendingpool
        STCLendingPoolV2::initialize(sender);
    }
}

//! new-transaction
//! sender: owner
address feeto = {{feeto}};
script {
    use 0x100000::STCLendingPoolV2;

    fun main(sender: signer) {
        STCLendingPoolV2::set_fee_to(sender, @feeto);
    }
}

// withdrawer init
//! new-transaction
//! sender: owner
script {
    use 0x100000::WithdrawerWithKiko;

    fun main(sender: signer) {
        WithdrawerWithKiko::initialize(sender);
    }
}

//! new-transaction
//! sender: swaper
script {
    use 0x1::STC::STC;
    use 0x100000::SHARE;
    use 0x100000::WEN;
    use 0x400000::SwapPair;
    use 0x400000::SwapConfig;
    fun main(sender: signer) {
        SwapConfig::initialize(&sender, 30, 5, 0, 0, 0, 0, 0);
        SwapPair::create_pair<STC, WEN::WEN>(&sender);
        SwapPair::create_pair<STC, SHARE::SHARE>(&sender);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86500000

// add lp
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::SHARE;
    use 0x100000::WEN;
    use 0x400000::SwapRouter;
    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let amount = 5000 * 1000 * 1000 * 1000; // 5000 stc

        // mint 5000 WEN
        WEN::mint_to(&sender, addr, amount / 10);
        // mint 500000 share
        SHARE::mint(&sender, addr, amount * 100);

        // stc-wen  5000 : 500
        SwapRouter::add_liquidity<STC, WEN::WEN>(&sender, amount, amount / 10, 0, 0);

        // stc-share  5000 : 500000
        SwapRouter::add_liquidity<STC, SHARE::SHARE>(&sender, amount, amount * 100, 0, 0);
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
//! block-time: 86600000

// bob deposit and borrow
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Account;
    use 0x100000::STCLendingPoolV2;
    use 0x100000::WEN::WEN;

    fun main(sender: signer) {

        let actions = Vector::empty<u8>();
        // ACTION_ADD_COLLATERAL
        Vector::push_back<u8>(&mut actions, 1);
        // ACTION_BORROW
        Vector::push_back<u8>(&mut actions, 3);

        let addr = Signer::address_of(&sender);
        let scale = 1000 * 1000 * 1000;

        let before = Account::balance<WEN>(addr);

        STCLendingPoolV2::cook(
            sender,
            actions,
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
//! block-number: 3
//! block-time: 86700000

//! new-transaction
//! sender: owner
script {
    use 0x100000::SSHARE;

    fun main(sender: signer) {
        SSHARE::initialize(sender);
        assert(SSHARE::balance() == 0, 400);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 86800000

// alice can not withdraw fee
// check: ABORTED
//! new-transaction
//! sender: alice
script {
    use 0x100000::WithdrawerWithKiko as Withdrawer;

    fun main(sender: signer) {
        assert(Withdrawer::balance() == 0, 200);
        Withdrawer::withdraw_and_swap(sender);
    }
}

// feeto can withdraw fee
//! new-transaction
//! sender: feeto
script {
    use 0x1::Account;
    use 0x100000::SSHARE;
    use 0x100000::WEN::WEN;
    use 0x100000::WithdrawerWithKiko as Withdrawer;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
        assert(Withdrawer::balance() == 0, 300);
        Withdrawer::withdraw_and_swap(sender);
        assert(Withdrawer::balance() > 0, 301);
        assert(SSHARE::balance() > 0, 302);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 5
//! block-time: 86900000

//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x100000::WithdrawerWithKiko as Withdrawer;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let balance = Withdrawer::balance();

        Withdrawer::withdraw(sender, addr, balance);

        assert(Withdrawer::balance() == 0, 600);
    }
}

//! new-transaction
//! sender: owner
script {
    use 0x100000::WithdrawerWithKiko as Withdrawer;

    fun main(sender: signer) {
        Withdrawer::destroy(sender);
    }
}
