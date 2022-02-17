//! account: alice, 0x123, 100 000 000 000
//! account: bob,   0x124, 100 000 000 000
//! account: feeto, 0x125, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init mock token
//! sender: owner
script {
    use 0x1::Signer;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        MockToken::initialize(&sender);
        MockToken::mint(&sender, Signer::address_of(&sender), 1000 * 1000 * 1000);
    }
}

//! new-transaction
//! sender: alice
script {
    use 0x1::Account;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        Account::do_accept_token<MockToken::USD>(&sender);
    }
}

// owner mint mock token to alice
//! new-transaction
//! sender: owner
address alice = {{alice}};
script {
    use 0x100000::MockToken;

    fun main(sender: signer) {
        MockToken::mint(&sender, @alice, 1000 * 1000 * 1000);
    }
}

// bob can not register
// check:ABORTED
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        LendingPool::initialize<TestLP::STC_POOL, STC, MockToken::USD>(
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

// lendingpool owner can register
//! new-transaction
//! sender: owner
address bob = {{bob}};
script {
    use 0x1::STC::STC;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        LendingPool::initialize<TestLP::STC_POOL, STC, MockToken::USD>(
            &sender,
            90000, // collaterization_rate 90%
            105000, // liquidation_multiplier 105%
            5000, // borrow_opening_fee 5%
            2500, // interest_per_second 2.5%
            100 * 1000 * 1000, // deposit amount
            b"TEST", // poll name
        );

        let (borrowed, _, left_to_borrow) = LendingPool::borrow_info<TestLP::STC_POOL, MockToken::USD>();
        assert(borrowed == 0, 101);
        assert(left_to_borrow == 100 * 1000 * 1000, 102);

        let total_collateral = LendingPool::collateral_info<TestLP::STC_POOL, STC>();
        assert(total_collateral == 0, 103);

        let (collateral, borrow) = LendingPool::position<TestLP::STC_POOL>(@bob);
        assert(collateral == 0, 104);
        assert(borrow == 0, 105);

        let (cr, lm, bof, ips) = LendingPool::pool_info<TestLP::STC_POOL>();
        assert(cr == 90000, 106);
        assert(lm == 105000, 107);
        assert(bof == 5000, 108);
        assert(ips == 2500, 109);

        // check solvent
        assert(LendingPool::is_solvent<TestLP::STC_POOL, MockToken::USD>(@bob, 0), 110);
    }
}

// bob add collateral
//! new-transaction
//! sender: bob
script {
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let old_balance = Account::balance<STC>(addr);
        LendingPool::add_collateral<TestLP::STC_POOL, STC>(&sender, 50 * 1000 * 1000);
        let balance = Account::balance<STC>(addr);
        assert(old_balance > balance, 201);

        let total_collateral = LendingPool::collateral_info<TestLP::STC_POOL, STC>();
        assert(total_collateral == 50 * 1000 * 1000, 202);

        LendingPool::remove_collateral<TestLP::STC_POOL, STC, MockToken::USD>(&sender, addr, 10 * 1000 * 1000);
        let total_collateral = LendingPool::collateral_info<TestLP::STC_POOL, STC>();
        assert(total_collateral == 40 * 1000 * 1000, 203);
    }
}

// alice can not borrow
// check:ABORTED
//! new-transaction
//! sender: alice
script {
    use 0x1::Signer;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        LendingPool::borrow<TestLP::STC_POOL, MockToken::USD>(&sender, addr, 10 * 1000 * 1000);
    }
}
// check:ABORTED

// bob can borrow
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert(Account::balance<MockToken::USD>(addr) == 0, 301);
        LendingPool::borrow<TestLP::STC_POOL, MockToken::USD>(&sender, addr, 10 * 1000 * 1000);
        assert(Account::balance<MockToken::USD>(addr) == 10 * 1000 * 1000, 302);

        let (collateral, borrow) = LendingPool::position<TestLP::STC_POOL>(addr);
        assert(collateral == 40 * 1000 * 1000, 303);

        //borrow_opening_fee 5%
        assert(borrow == 10 * 1000 * 1000 + 500 * 1000, 304);
    }
}

// bob can repay
//! new-transaction
//! sender: bob
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let repay_part = 1 * 1000 * 1000;
        let before_b = Account::balance<MockToken::USD>(addr);
        let (_, before_borrow) = LendingPool::position<TestLP::STC_POOL>(addr);

        LendingPool::repay<TestLP::STC_POOL, MockToken::USD>(&sender, addr, repay_part);

        let after_b = Account::balance<MockToken::USD>(addr);
        let (_, after_borrow) = LendingPool::position<TestLP::STC_POOL>(addr);

        assert(before_b > after_b, 401);
        assert(before_borrow > after_borrow, 402);
        assert((before_borrow - after_borrow) == repay_part, 403);
    }
}

// alice can repay bob
//! new-transaction
//! sender: alice
address bob = {{bob}};
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let repay_part = 1 * 1000 * 1000;
        let before_b = Account::balance<MockToken::USD>(addr);
        let (_, before_borrow) = LendingPool::position<TestLP::STC_POOL>(@bob);

        LendingPool::repay<TestLP::STC_POOL, MockToken::USD>(&sender, @bob, repay_part);

        let after_b = Account::balance<MockToken::USD>(addr);
        let (_, after_borrow) = LendingPool::position<TestLP::STC_POOL>(@bob);

        assert(before_b > after_b, 501);
        assert(before_borrow > after_borrow, 502);
        assert((before_borrow - after_borrow) == repay_part, 503);
    }
}

// alice can not set feeTo
// check:ABORTED
//! new-transaction
//! sender: alice
script {
    use 0x1::Signer;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        LendingPool::set_fee_to<TestLP::STC_POOL>(&sender, addr);
    }
}
// check:ABORTED

// owner can set feeto
//! new-transaction
//! sender: owner
address feeto = {{feeto}};
script {
    use 0x100000::LendingPool;
    use 0x100000::TestLP;

    fun main(sender: signer) {
        let (fee_to_address, _, _) = LendingPool::fee_info<TestLP::STC_POOL>();
        assert(fee_to_address != @feeto, 601);

        LendingPool::set_fee_to<TestLP::STC_POOL>(&sender, @feeto);

        let (fee_to_address, _, _) = LendingPool::fee_info<TestLP::STC_POOL>();
        assert(fee_to_address == @feeto, 602);
    }
}

// deprecated
//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::STC::STC;
    use 0x100000::LendingPool;
    use 0x100000::TestLP;
    use 0x100000::MockToken;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert(!LendingPool::is_deprecated<TestLP::STC_POOL>(), 701);
        LendingPool::deprecated<TestLP::STC_POOL, STC, MockToken::USD>(&sender, addr, 0, 0);
        LendingPool::deprecated<TestLP::STC_POOL, STC, MockToken::USD>(&sender, addr, 100, 100);
        assert(LendingPool::is_deprecated<TestLP::STC_POOL>(), 702);
    }
}
