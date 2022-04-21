//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol

//# faucet --addr alice

// init share
//# run --signers WenProtocol
script {
    use WenProtocol::SHARE;
    use WenProtocol::SHARETeamTreasury;

    fun main(sender: signer) {
        SHARE::initialize(&sender);
        SHARETeamTreasury::initialize(sender);
    }
}


//# run --signers alice
script {
    use WenProtocol::SHARE;
    use WenProtocol::SHARETeamTreasury;

    fun main(_sender: signer) {
        let max = SHARE::get_max_supply();
        assert!(SHARETeamTreasury::balance() == max * 20 / 100, 1001);
    }
}


//# block --author 0x1 --timestamp 1000000

//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::SHARE::SHARE;
    use WenProtocol::SHARETeamTreasury;

    fun main(sender: signer) {
        let addr = Signer::address_of(&sender);
        assert!(Account::balance<SHARE>(addr) == 0, 2001);
        SHARETeamTreasury::withdraw(sender, addr);
        assert!(Account::balance<SHARE>(addr) > 0, 2002);
    }
}


// 3 years later

//# block --author 0x1 --timestamp 94609000000

//# run --signers WenProtocol
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use WenProtocol::SHARE;
    use WenProtocol::SHARETeamTreasury;

    fun main(sender: signer) {
        let max = SHARE::get_max_supply();
        let addr = Signer::address_of(&sender);
        SHARETeamTreasury::withdraw(sender, addr);
        assert!(Account::balance<SHARE::SHARE>(addr) == max * 20 / 100, 3001);
    }
}
