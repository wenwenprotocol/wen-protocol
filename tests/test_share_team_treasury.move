//! account: alice, 0x123, 100 000 000 000
//! account: owner, 0x100000,  200 000 000

// init share
//! sender: owner
script {
    use 0x100000::SHARE;
    use 0x100000::SHARETeamTreasury;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
        SHARETeamTreasury::initialize(sender);
    }
}

//! new-transaction
//! sender: alice
script {
    use 0x100000::SHARE;
    use 0x100000::SHARETeamTreasury;

    fun main(_sender: signer) {
        let max = SHARE::get_max_supply();
        assert(SHARETeamTreasury::balance() == max * 20 / 100, 1001);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 1000000

//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::SHARE::SHARE;
    use 0x100000::SHARETeamTreasury;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert(Account::balance<SHARE>(addr) == 0, 2001);
        SHARETeamTreasury::withdraw(sender, addr);
        assert(Account::balance<SHARE>(addr) > 0, 2002);
    }
}

// 3 years later
//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 94609000000

//! new-transaction
//! sender: owner
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x100000::SHARE;
    use 0x100000::SHARETeamTreasury;

    fun main(sender: signer) {
        let max = SHARE::get_max_supply();
        let addr = Signer::address_of(&sender);
        SHARETeamTreasury::withdraw(sender, addr);
        assert(Account::balance<SHARE::SHARE>(addr) == max * 20 / 100, 3001);
    }
}