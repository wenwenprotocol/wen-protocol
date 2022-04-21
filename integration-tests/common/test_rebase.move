//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol --amount 200000000

//# faucet --addr alice --amount 100000000000

//# faucet --addr bob --amount 100000000000

//# publish
module WenProtocol::TestRebase {
    struct TestRebase has store {}
}

//# run --signers WenProtocol
script {
    use WenProtocol::Rebase;
    use WenProtocol::TestRebase;

    fun main(sender: signer) {
        Rebase::initialize<TestRebase::TestRebase>(&sender);
    }
}

// check elastic -> base
//# run --signers alice
script {
    use WenProtocol::Rebase;
    use WenProtocol::TestRebase::TestRebase;

    fun main(sender: signer) {
        // init
        Rebase::initialize<TestRebase>(&sender);
        // get elastic and base
        let (e, b) = Rebase::get<TestRebase>(@alice);
        assert!(e == 0, 102);
        assert!(b == 0, 103);
        // toBase ( when elastic = 0 , base = input)
        assert!(100 == Rebase::toBase<TestRebase>(@alice, 100, true), 101);
        // add eleasic and base
        Rebase::add<TestRebase>(&sender, 100, 100);
        // toBase (when elastic !=0 , base = (elastic * total_base/total_elastic))
        assert!(200 * 100 / 100 == Rebase::toBase<TestRebase>(@alice, 200, true), 102);

        // sub elastic and base (total_elastic = 100-67=33, total_base = 100-0=100)
        Rebase::sub<TestRebase>(&sender, 67, 0);
        // roundUp = false
        assert!(200 * 100 / 33 == Rebase::toBase<TestRebase>(@alice, 200, false), 103);
        // roundUp = true
        assert!(200 * 100 / 33 + 1 == Rebase::toBase<TestRebase>(@alice, 200, true), 104);

        assert!(33 * 100 / 33 == Rebase::toBase<TestRebase>(@alice, 33, false), 104);
        assert!(33 * 100 / 33 == Rebase::toBase<TestRebase>(@alice, 33, true), 104);

        // add elastic and base by elastic
        Rebase::addByElastic<TestRebase>(&sender, 33, true);
        let (e, b) = Rebase::get<TestRebase>(@alice);
        assert!(e == 33 + 33, 105);
        assert!(b == 100 + 33 * 100/33, 106);
    }
}

// check base -> elastic
//# run --signers bob
script {
    use WenProtocol::Rebase;
    use WenProtocol::TestRebase::TestRebase;

    fun main(sender: signer) {
        // init
        Rebase::initialize<TestRebase>(&sender);
        // get elastic and base
        let (e, b) = Rebase::get<TestRebase>(@bob);
        assert!(e == 0, 201);
        assert!(b == 0, 202);
        // toElastic ( when total_base = 0 , elastic = input)
        assert!(100 == Rebase::toElastic<TestRebase>(@bob, 100, true), 203);
        // add eleasic and base
        Rebase::add<TestRebase>(&sender, 100, 100);
        // toElastic (when total_base !=0 , elastic = (base * total_elastic/total_base))
        assert!(200 * 100 / 100 == Rebase::toElastic<TestRebase>(@bob, 200, true), 204);

        // sub elastic and base (total_elastic = 100-0=100, total_base = 100-67=33)
        Rebase::sub<TestRebase>(&sender, 0, 67);
        // roundUp = false
        assert!(200 * 100 / 33 == Rebase::toElastic<TestRebase>(@bob, 200, false), 205);
        // roundUp = true
        assert!(200 * 100 / 33 + 1 == Rebase::toElastic<TestRebase>(@bob, 200, true), 206);

        assert!(33 * 100 / 33 == Rebase::toElastic<TestRebase>(@bob, 33, false), 207);
        assert!(33 * 100 / 33 == Rebase::toElastic<TestRebase>(@bob, 33, true), 208);

        // sub elastic and base by base
        Rebase::subByBase<TestRebase>(&sender, 33, true);
        let (e, b) = Rebase::get<TestRebase>(@bob);
        assert!(e == 100 - 33 * 100 / 33, 209);
        assert!(b == 33 - 33, 210);
    }
}
