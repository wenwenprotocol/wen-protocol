//! account: alice, 0x123, 100000000000
//! account: bob,   0x124, 100000000000
//! account: owner, 0x100000,  200000000

// init
//! sender: owner
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(sender: signer) {
        Permission::register_permission<TestPermission::TestPermission>(&sender);
    }
}

// bob can register
// check:ABORTED
//! new-transaction
//! sender: bob
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(sender: signer) {
        Permission::register_permission<TestPermission::TestPermission>(&sender);
    }
}

// add
//! new-transaction
//! sender: owner
address alice = {{alice}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(sender: signer) {
        Permission::add<TestPermission::TestPermission>(&sender, @alice);
    }
}

// check length
//! new-transaction
//! sender: bob
address owner = {{owner}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(_sender: signer) {
        assert(
            Permission::total<TestPermission::TestPermission>(@owner) == 1,
            100,
        );
    }
}

// check can
//! new-transaction
//! sender: owner
address bob = {{bob}};
address alice = {{alice}};
address owner = {{owner}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(_sender: signer) {
        // bob can not
        assert(!Permission::can<TestPermission::TestPermission>(@bob), 101);
        // owner and alice can
        assert(Permission::can<TestPermission::TestPermission>(@alice), 102);
        assert(Permission::can<TestPermission::TestPermission>(@owner), 103);
    }
}

// remove
//! new-transaction
//! sender: owner
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(sender: signer) {
        Permission::remove<TestPermission::TestPermission>(&sender, @alice);
        Permission::remove<TestPermission::TestPermission>(&sender, @bob);
    }
}

// check can
//! new-transaction
//! sender: alice
address bob = {{bob}};
address alice = {{alice}};
address owner = {{owner}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(_sender: signer) {
        // bob alice  can not
        assert(!Permission::can<TestPermission::TestPermission>(@bob), 201);
        assert(!Permission::can<TestPermission::TestPermission>(@alice), 202);
        // owner can
        assert(Permission::can<TestPermission::TestPermission>(@owner), 203);
    }
}

// check length
//! new-transaction
//! sender: bob
address owner = {{owner}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(_sender: signer) {
        assert(
            Permission::total<TestPermission::TestPermission>(@owner) == 0,
            301,
        );
    }
}

// check owner
//! new-transaction
//! sender: alice
address bob = {{bob}};
address alice = {{alice}};
address owner = {{owner}};
script {
    use 0x100000::TestPermission;
    use 0x100000::Permission;

    fun main(_sender: signer) {
        assert(!Permission::is_owner<TestPermission::TestPermission>(@bob), 301);
        assert(!Permission::is_owner<TestPermission::TestPermission>(@alice), 302);
        assert(Permission::is_owner<TestPermission::TestPermission>(@owner), 303);
    }
}
