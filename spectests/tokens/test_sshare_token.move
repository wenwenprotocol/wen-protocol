//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr alice

// init sshare
//# run --signers WenProtocol
script {
    use WenProtocol::SHARE;
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
        SSHARE::initialize(sender);
    }
}

// accept share
//# run --signers alice
script {
    use StarcoinFramework::Account;
    use WenProtocol::SHARE::SHARE;

    fun main(sender: signer) {
        Account::do_accept_token<SHARE>(&sender);
    }
}


// mint share to alice
//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use WenProtocol::SHARE;

    fun main(sender: signer) {
        SHARE::mint(&sender, Signer::address_of(&sender), 1000 * 1000 * 1000 * 1000);
        SHARE::mint(&sender, @alice, 1000 * 1000 * 1000 * 1000);
    }
}


// alice get balance
//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert!(Account::balance<SSHARE::SSHARE>(addr) == 0, 101);
        let (b, _) = SSHARE::balance_of(addr);
        assert!(b == 0, 102);
        assert!(SSHARE::total_supply() == 0, 103);
        assert!(SSHARE::balance() == 0, 104);
    }
}


//# block --author 0x1 --timestamp 500000

// alice mint => locktime = 500 + 86400 = 86900
//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use WenProtocol::SSHARE;
    use WenProtocol::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let share_amount = 10 * 1000 * 1000 * 1000;

        let balance_before = Account::balance<SHARE::SHARE>(addr);
        SSHARE::mint(sender, share_amount);
        let balance_after = Account::balance<SHARE::SHARE>(addr);

        assert!((balance_after + share_amount) == balance_before, 201);
        assert!(SSHARE::balance() == share_amount, 202);
        assert!(SSHARE::total_supply() == share_amount, 203);
        let (b, _) = SSHARE::balance_of(addr);
        assert!(b == share_amount, 204);
        assert!(Account::balance<SSHARE::SSHARE>(addr) == 0, 205);
        assert!(SSHARE::locked_balance() == share_amount, 206);
    }
}


//# block --author 0x1 --timestamp 600000

// alice mint => locktime = 600 + 86400 = 87000
//# run --signers alice
script {
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        let share_amount = 10 * 1000 * 1000 * 1000;
        SSHARE::mint(sender, share_amount);
    }
}


//# block --author 0x1 --timestamp 86900000

// alice mint => locktime = 600 + 86400 = 87000
//# run --signers alice
script {
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        SSHARE::claim(sender);
    }
}
// check: "Keep(ABORTED { code: 102"


//# block --author 0x1 --timestamp 87000000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);

        // before
        let (b, _) = SSHARE::balance_of(addr);
        assert!(b > 0, 401);
        assert!(Account::balance<SSHARE::SSHARE>(addr) == 0, 402);

        // claim
        SSHARE::claim(sender);

        // after
        let (b, _) = SSHARE::balance_of(addr);
        assert!(b == 0, 403);
        assert!(Account::balance<SSHARE::SSHARE>(addr) > 0, 404);
    }
}


// deposit
//# run --signers WenProtocol
script {
    use WenProtocol::SSHARE;

    fun main(sender: signer) {
        let balance_before = SSHARE::balance();
        SSHARE::deposit(sender, 10 * 1000 * 1000 * 1000);
        let balance_after = SSHARE::balance();
        assert!(balance_before < balance_after, 501);
    }
}


// burn
//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::SSHARE;
    use WenProtocol::SHARE;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        let sshare_amount = SSHARE::total_supply();
        let share_amount = SSHARE::balance();
        let balance_before = Account::balance<SSHARE::SSHARE>(addr);
        let share_balance_before = Account::balance<SHARE::SHARE>(addr);

        // burn
        let burn_sshare_amount = 10 * 1000 * 1000 * 1000;
        SSHARE::burn(sender, burn_sshare_amount);

        let got_share_amount = burn_sshare_amount * share_amount / sshare_amount;
        let balance_after = Account::balance<SSHARE::SSHARE>(addr);
        let share_balance_after = Account::balance<SHARE::SHARE>(addr);

        assert!(balance_before - burn_sshare_amount == balance_after, 601);
        assert!(share_balance_before + got_share_amount == share_balance_after, 602);
    }
}
