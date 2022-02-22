//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr alice

//# faucet --addr bob

//# faucet --addr feeto


// init mock token
//# run --signers WenProtocol
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        MockToken::initialize(&sender, 1000 * 1000 * 1000);
    }
}


//# run --signers alice
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        MockToken::accept_token(&sender);
    }
}


// owner mint mock token to alice
//# run --signers WenProtocol
script {
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        MockToken::mint(&sender, @alice, 1000 * 1000 * 1000);
    }
}


// bob can not register
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        LendingPool::initialize<LPTestHelper::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            105000, // liquidation_multiplier
            5000, // borrow_opening_fee
            2500, // interest_per_second
            0, // deposit amount
            b"TEST", // poll name
        );
    }
}
// check:ABORTED


// lendingpool owner can register
//# run --signers WenProtocol
script {
    use StarcoinFramework::STC::STC;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        LendingPool::initialize<LPTestHelper::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            2500, // interest_per_second 2.5%
            100 * 1000 * 1000, // deposit amount
            b"TEST", // poll name
        );

        let (borrowed, _, left_to_borrow) = LendingPool::borrow_info<LPTestHelper::STC_POOL, MockToken::USD>();
        assert!(borrowed == 0, 101);
        assert!(left_to_borrow == 100 * 1000 * 1000, 102);

        let total_collateral = LendingPool::collateral_info<LPTestHelper::STC_POOL, STC>();
        assert!(total_collateral == 0, 103);

        let (collateral, borrow) = LendingPool::position<LPTestHelper::STC_POOL>(@bob);
        assert!(collateral == 0, 104);
        assert!(borrow == 0, 105);

        let (cr, lm, bof, ips) = LendingPool::pool_info<LPTestHelper::STC_POOL>();
        assert!(cr == 90000, 106);
        assert!(lm == 105000, 107);
        assert!(bof == 5000, 108);
        assert!(ips == 2500, 109);

        // check solvent
        assert!(LendingPool::is_solvent<LPTestHelper::STC_POOL, MockToken::USD>(@bob, 0), 110);
    }
}


// bob add collateral
//# run --signers bob
script {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let old_balance = Account::balance<STC>(addr);
        LendingPool::add_collateral<LPTestHelper::STC_POOL, STC>(&sender, 50 * 1000 * 1000);
        let balance = Account::balance<STC>(addr);
        assert!(old_balance > balance, 201);

        let total_collateral = LendingPool::collateral_info<LPTestHelper::STC_POOL, STC>();
        assert!(total_collateral == 50 * 1000 * 1000, 202);

        LendingPool::remove_collateral<LPTestHelper::STC_POOL, STC, MockToken::USD>(&sender, addr, 10 * 1000 * 1000);
        let total_collateral = LendingPool::collateral_info<LPTestHelper::STC_POOL, STC>();
        assert!(total_collateral == 40 * 1000 * 1000, 203);
    }
}


// alice can not borrow
//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        LendingPool::borrow<LPTestHelper::STC_POOL, MockToken::USD>(&sender, addr, 10 * 1000 * 1000);
    }
}
// check:ABORTED


// bob can borrow
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert!(Account::balance<MockToken::USD>(addr) == 0, 301);
        LendingPool::borrow<LPTestHelper::STC_POOL, MockToken::USD>(&sender, addr, 10 * 1000 * 1000);
        assert!(Account::balance<MockToken::USD>(addr) == 10 * 1000 * 1000, 302);

        let (collateral, borrow) = LendingPool::position<LPTestHelper::STC_POOL>(addr);
        assert!(collateral == 40 * 1000 * 1000, 303);

        //borrow_opening_fee 5%
        assert!(borrow == 10 * 1000 * 1000 + 500 * 1000, 304);
    }
}


// bob can repay
//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let repay_part = 1 * 1000 * 1000;
        let before_b = Account::balance<MockToken::USD>(addr);
        let (_, before_borrow) = LendingPool::position<LPTestHelper::STC_POOL>(addr);

        LendingPool::repay<LPTestHelper::STC_POOL, MockToken::USD>(&sender, addr, repay_part);

        let after_b = Account::balance<MockToken::USD>(addr);
        let (_, after_borrow) = LendingPool::position<LPTestHelper::STC_POOL>(addr);

        assert!(before_b > after_b, 401);
        assert!(before_borrow > after_borrow, 402);
        assert!((before_borrow - after_borrow) == repay_part, 403);
    }
}


// alice can repay bob
//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let repay_part = 1 * 1000 * 1000;
        let before_b = Account::balance<MockToken::USD>(addr);
        let (_, before_borrow) = LendingPool::position<LPTestHelper::STC_POOL>(@bob);

        LendingPool::repay<LPTestHelper::STC_POOL, MockToken::USD>(&sender, @bob, repay_part);

        let after_b = Account::balance<MockToken::USD>(addr);
        let (_, after_borrow) = LendingPool::position<LPTestHelper::STC_POOL>(@bob);

        assert!(before_b > after_b, 501);
        assert!(before_borrow > after_borrow, 502);
        assert!((before_borrow - after_borrow) == repay_part, 503);
    }
}

// alice can not set feeTo
//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        LendingPool::set_fee_to<LPTestHelper::STC_POOL>(&sender, addr);
    }
}
// check:ABORTED


// owner can set feeto
//# run --signers WenProtocol
script {
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        let (fee_to_address, _, _) = LendingPool::fee_info<LPTestHelper::STC_POOL>();
        assert!(fee_to_address != @feeto, 601);

        LendingPool::set_fee_to<LPTestHelper::STC_POOL>(&sender, @feeto);

        let (fee_to_address, _, _) = LendingPool::fee_info<LPTestHelper::STC_POOL>();
        assert!(fee_to_address == @feeto, 602);
    }
}

// deprecated
//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use WenProtocol::LendingPool;
    use WenProtocol::LPTestHelper;
    use WenProtocol::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert!(!LendingPool::is_deprecated<LPTestHelper::STC_POOL>(), 701);
        LendingPool::deprecated<LPTestHelper::STC_POOL, STC, MockToken::USD>(&sender, addr, 0, 0);
        LendingPool::deprecated<LPTestHelper::STC_POOL, STC, MockToken::USD>(&sender, addr, 100, 100);
        assert!(LendingPool::is_deprecated<LPTestHelper::STC_POOL>(), 702);
    }
}
