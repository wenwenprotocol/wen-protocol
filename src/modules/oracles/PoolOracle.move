address 0x100000 {
module PoolOracle {
    use 0x1::Timestamp;
    use 0x1::Event;
    use 0x1::Token;
    use 0x1::Signer;

    use 0x100000::SafeMath;
    use 0x100000::StcPoolOracle;

    struct UpdateEvent has drop, store {}

    struct Price<PoolType> has key, store {
        oracle_name: vector<u8>,
        exchange_rate: u128,
        scaling_factor: u128,
        last_updated: u64,
        events: Event::EventHandle<UpdateEvent>,
    }
    // 1e12
    const PRECISION: u128 = 1000000 * 1000000;

    // error code
    const ERR_NOT_REGISTER: u64 = 201;
    const ERR_NOT_AUTHORIZED: u64 = 202;
    const ERR_NOT_EXIST : u64 = 203;

    // get T issuer
    fun t_address<T: store>(): address { Token::token_address<T>() }

    fun assert_is_register<PoolType: store>(): address {
        let owner = t_address<PoolType>();
        assert(exists<Price<PoolType>>(owner), ERR_NOT_REGISTER);
        owner
    }

    // only PoolType's issuer can register
    public fun register<PoolType: store>(account: &signer, oracle_name: vector<u8>) {
        assert(Signer::address_of(account) == t_address<PoolType>(), ERR_NOT_AUTHORIZED);
        move_to(
            account,
            Price<PoolType> {
                oracle_name: oracle_name,
                exchange_rate: 0,
                scaling_factor: 0,
                last_updated: Timestamp::now_seconds(),
                events: Event::new_event_handle<UpdateEvent>(account),
            },
        );
    }

    public fun get<PoolType: store>(): (u128, u128, u64) acquires Price {
        let owner = assert_is_register<PoolType>();
        let price = borrow_global<Price<PoolType>>(owner);
        (price.exchange_rate, price.scaling_factor, price.last_updated)
    }

    public fun latest_price<PoolType: store>(): (u128, u128) acquires Price {
        let owner = assert_is_register<PoolType>();
        let name = *&borrow_global<Price<PoolType>>(owner).oracle_name;
        if (name == b"STC_POOL") {
            StcPoolOracle::get()
        } else {
            (0, 0)
        }
    }

    public fun latest_exchange_rate<PoolType: store>(): (u128, u128) acquires Price {
        let (e, s) = latest_price<PoolType>();
        if (e > 0) {
            (SafeMath::safe_mul_div(s, PRECISION, e), PRECISION)
        } else {
            (0, 0)
        }
    }

    public fun update<PoolType: store>(): (u128, u128) acquires Price {
        let (e, s) = latest_price<PoolType>();
        if (e > 0) {
            do_update<PoolType>(e, s)
        } else {
            (0, 0)
        }
    }

    // how much collateral to buy 1 WEN
    fun do_update<PoolType: store>(exchange_rate: u128, scaling_factor: u128): (u128, u128) acquires Price {
        let price = borrow_global_mut<Price<PoolType>>(t_address<PoolType>());
        let new_exchange_rate = SafeMath::safe_mul_div(scaling_factor, PRECISION, exchange_rate);
        price.exchange_rate = new_exchange_rate;
        price.scaling_factor = PRECISION;
        price.last_updated = Timestamp::now_seconds();
        Event::emit_event(&mut price.events, UpdateEvent {});
        (new_exchange_rate, PRECISION)
    }
}
}