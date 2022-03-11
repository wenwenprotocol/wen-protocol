address WenProtocol {
module Permission {
    use StarcoinFramework::Event;
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;

    struct Permission<phantom PermType> has key, store {
        addresses: vector<address>,
        events: Event::EventHandle<UpdateEvent>,
    }

    struct UpdateEvent has drop, store {
        action: u8,     // 0 for remove, 1 for add
        addr: address,
    }

    const PERMISSION_CAN_NOT_REGISTER: u64 = 101;
    const PERMISSION_NOT_EXISTS: u64 = 102;

    fun owner_address<PermType: store>(): address {
        // get the T-type address
        Token::token_address<PermType>()
    }

    // only permType owner can register
    public fun register_permission<PermType: store>(account: &signer) {
        let owner = owner_address<PermType>();
        assert!(Signer::address_of(account) == owner, PERMISSION_CAN_NOT_REGISTER);
        move_to(
            account,
            Permission<PermType> {
                addresses: Vector::empty<address>(),
                events: Event::new_event_handle<UpdateEvent>(account),
            },
        );
    }

    public fun add<PermType: store>(account: &signer, to: address) acquires Permission {
        let account_addr = Signer::address_of(account);
        assert!(exists<Permission<PermType>>(account_addr), PERMISSION_NOT_EXISTS);
        let perm = borrow_global_mut<Permission<PermType>>(account_addr);
        Vector::push_back<address>(&mut perm.addresses, to);
        Event::emit_event(
            &mut perm.events,
            UpdateEvent { addr: to, action: 1 },
        );
    }

    public fun remove<PermType: store>(account: &signer, to: address) acquires Permission {
        let account_addr = Signer::address_of(account);
        assert!(exists<Permission<PermType>>(account_addr), PERMISSION_NOT_EXISTS);
        let perm = borrow_global_mut<Permission<PermType>>(account_addr);
        let addresses = &mut perm.addresses;
        let (is_exists, index) = Vector::index_of<address>(addresses, &to);
        if (is_exists) {
            Vector::remove<address>(addresses, index);
            Event::emit_event(
                &mut perm.events,
                UpdateEvent { addr: to, action: 0 },
            );
        };
    }

    public fun can<PermType: store>(addr: address): bool acquires Permission {
        let owner = owner_address<PermType>();
        if (owner == addr) {
            return true
        };
        let perm = borrow_global<Permission<PermType>>(owner);
        Vector::contains<address>(&perm.addresses, &addr)
    }

    public fun total<PermType: store>(owner: address): u64 acquires Permission {
        assert!(exists<Permission<PermType>>(owner), PERMISSION_NOT_EXISTS);
        let perm = borrow_global<Permission<PermType>>(owner);
        Vector::length<address>(&perm.addresses)
    }

    public fun is_owner<PermType: store>(addr: address): bool {
        owner_address<PermType>() == addr
    }
}
}
