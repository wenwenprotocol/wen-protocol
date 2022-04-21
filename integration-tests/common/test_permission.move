//# init -n test --public-keys WenProtocol=0x07d815b1ef166cbba8dc80e6e2f0e50e3461551ca118a6587632e615123139a6

//# faucet --addr WenProtocol --amount 200000000

//# faucet --addr alice --amount 100000000000

//# faucet --addr bob --amount 100000000000

//# publish
module WenProtocol::TestPermission {
    struct TestPermission has store {}
}


//# run --signers WenProtocol
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(sender: signer) {
        Permission::register_permission<TestPermission::TestPermission>(&sender);
    }
}


// bob can not register
//# run --signers bob
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(sender: signer) {
        Permission::register_permission<TestPermission::TestPermission>(&sender);
    }
}
// check: "Keep(ABORTED { code: 101"


// add
//# run --signers WenProtocol
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(sender: signer) {
        Permission::add<TestPermission::TestPermission>(&sender, @alice);
    }
}

// check length
//# run --signers bob
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(_sender: signer) {
        assert!(
            Permission::total<TestPermission::TestPermission>(@WenProtocol) == 1,
            100,
        );
    }
}

// check can
//# run --signers WenProtocol
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(_sender: signer) {
        // bob can not
        assert!(!Permission::can<TestPermission::TestPermission>(@bob), 101);
        // WenProtocol and alice can
        assert!(Permission::can<TestPermission::TestPermission>(@alice), 102);
        assert!(Permission::can<TestPermission::TestPermission>(@WenProtocol), 103);
    }
}

// remove
//# run --signers WenProtocol
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(sender: signer) {
        Permission::remove<TestPermission::TestPermission>(&sender, @alice);
        Permission::remove<TestPermission::TestPermission>(&sender, @bob);
    }
}

// check can
//# run --signers alice
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(_sender: signer) {
        // bob alice  can not
        assert!(!Permission::can<TestPermission::TestPermission>(@bob), 201);
        assert!(!Permission::can<TestPermission::TestPermission>(@alice), 202);
        // WenProtocol can
        assert!(Permission::can<TestPermission::TestPermission>(@WenProtocol), 203);
    }
}

// check length
//# run --signers bob
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(_sender: signer) {
        assert!(
            Permission::total<TestPermission::TestPermission>(@WenProtocol) == 0,
            301,
        );
    }
}

// check WenProtocol
//# run --signers alice
script {
    use WenProtocol::TestPermission;
    use WenProtocol::Permission;

    fun main(_sender: signer) {
        assert!(!Permission::is_owner<TestPermission::TestPermission>(@bob), 301);
        assert!(!Permission::is_owner<TestPermission::TestPermission>(@alice), 302);
        assert!(Permission::is_owner<TestPermission::TestPermission>(@WenProtocol), 303);
    }
}
