//# init -n dev --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6 --public-keys PublicOracle=0x671f257c6c31231bb272fb67e3090b1f6218010a2e7e31e677ce56924ae12074 --addresses PublicOracle=0x82e35b34096f32c42061717c06e44a59

//# faucet --addr WenProtocol

//# faucet --addr PublicOracle

//# faucet --addr alice

//# faucet --addr bob

// bob can not register
//# run --signers bob
script {
    use WenProtocol::PoolOracle;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        PoolOracle::register<LPTestHelper::STC_POOL>(&sender, b"STC_POOL");
    }
}
// check:ABORTED


// owner can register
//# run --signers WenProtocol
script {
    use WenProtocol::PoolOracle;
    use WenProtocol::LPTestHelper;

    fun main(sender: signer) {
        PoolOracle::register<LPTestHelper::STC_POOL>(&sender, b"STC_POOL");
    }
}


//# run --signers bob
script {
    use WenProtocol::PoolOracle;
    use WenProtocol::LPTestHelper;

    fun main(_sender: signer) {
        let (p, s, _) = PoolOracle::get<LPTestHelper::STC_POOL>();
        assert!(p == 0, 101);
        assert!(s == 0, 102);
    }
}


// init price
//# run --signers PublicOracle
script {
    use WenProtocol::OracleTestHelper;
    use WenProtocol::StcPoolOracle;

    fun main(sender: signer) {
        OracleTestHelper::init_data_source(sender, 1000 * 10000);

        // get
        let (price, scaling_factor) = StcPoolOracle::get();
        assert!(price == 1000 * 10000, 101);
        assert!(scaling_factor == 1000 * 1000, 102);
    }
}


// everybody can update
//# run --signers alice
script {
    use WenProtocol::PoolOracle;
    use WenProtocol::LPTestHelper;

    fun main(_sender: signer) {
        PoolOracle::update<LPTestHelper::STC_POOL>();

        let (p, s, _) = PoolOracle::get<LPTestHelper::STC_POOL>();

        // stc price = 1000 * 10000  => 1STC=10USD
        // p = 0.1 * s
        assert!(p == 1000000 * 100000, 301);
        assert!(s == 1000000 * 1000000, 302);
    }
}
