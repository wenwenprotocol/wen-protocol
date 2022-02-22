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
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use WenProtocol::STCLendingPoolV2;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
        WEN::initialize(&sender);
        // init stc Lendingpool
        STCLendingPoolV2::initialize(sender);
    }
}


//# run --signers WenProtocol
script {
    use WenProtocol::STCLendingPoolV2;

    fun main(sender: signer) {
        STCLendingPoolV2::set_fee_to(sender, @feeto);
    }
}


// withdrawer init
//# run --signers WenProtocol
script {
    use WenProtocol::WithdrawerWithStar;

    fun main(sender: signer) {
        WithdrawerWithStar::initialize(sender);
    }
}


//# run --signers StarSwap
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use StarSwap::TokenSwap;
    fun main(sender: signer) {
        TokenSwap::register_swap_pair<STC, WEN::WEN>(&sender);
        TokenSwap::register_swap_pair<STC, SHARE::SHARE>(&sender);
    }
}


//# block --author 0x1 --timestamp 86500000

// add lp
//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::SHARE;
    use WenProtocol::WEN;
    use StarSwap::TokenSwapRouter;
    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let amount = 5000 * 1000 * 1000 * 1000; // 5000 stc

        // mint 5000 WEN
        WEN::mint_to(&sender, addr, amount / 10);
        // mint 500000 share
        SHARE::mint(&sender, addr, amount * 100);

        // stc-wen  5000 : 500
        TokenSwapRouter::add_liquidity<STC, WEN::WEN>(&sender, amount, amount / 10, 0, 0);

        // stc-share  5000 : 500000
        TokenSwapRouter::add_liquidity<STC, SHARE::SHARE>(&sender, amount, amount * 100, 0, 0);
    }
}


//# block --author 0x1 --timestamp 86600000

// bob deposit and borrow
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Account;
    use WenProtocol::STCLendingPoolV2;
    use WenProtocol::WEN::WEN;

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

        assert!(before == 0, 100);
        assert!(after == 500 * scale, 101);
    }
}


//# block --author 0x1 --timestamp 86700000

//# run --signers WenProtocol
script {
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        SSHARE::initialize(sender);
        assert!(SSHARE::balance() == 0, 400);
    }
}

//# block --author 0x1 --timestamp 86800000

// alice can not withdraw fee
//# run --signers alice
script {
    use WenProtocol::WithdrawerWithStar as Withdrawer;

    fun main(sender: signer) {
        assert!(Withdrawer::balance() == 0, 200);
        Withdrawer::withdraw_and_swap(sender);
    }
}
// check: ABORTED


// feeto can withdraw fee
//# run --signers feeto
script {
    use StarcoinFramework::Account;
    use WenProtocol::SSHARE;
    use WenProtocol::WEN::WEN;
    use WenProtocol::WithdrawerWithStar as Withdrawer;

    fun main(sender: signer) {
        Account::do_accept_token<WEN>(&sender);
        assert!(Withdrawer::balance() == 0, 300);
        Withdrawer::withdraw_and_swap(sender);
        assert!(Withdrawer::balance() > 0, 301);
        assert!(SSHARE::balance() > 0, 302);
    }
}


//# block --author 0x1 --timestamp 86900000

//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use WenProtocol::WithdrawerWithStar as Withdrawer;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let balance = Withdrawer::balance();

        Withdrawer::withdraw(sender, addr, balance);

        assert!(Withdrawer::balance() == 0, 600);
    }
}


//# run --signers WenProtocol
script {
    use WenProtocol::WithdrawerWithStar as Withdrawer;

    fun main(sender: signer) {
        Withdrawer::destroy(sender);
    }
}
