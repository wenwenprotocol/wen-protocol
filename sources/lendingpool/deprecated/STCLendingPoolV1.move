address WenProtocol {
module STCLendingPoolV1 {
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;  // Collateral
    use WenProtocol::WEN::{Self, WEN};    // Stable Coin
    use WenProtocol::LendingPool;

    // Pool Type
    struct STC_POOL has store {}

    const ORACLE_NAME: vector<u8> = b"STC_POOL";
    const COLLATERIZATION_RATE: u128 = 75000;       // 75%
    const LIQUIDATION_MULTIPLIER: u128 = 107500;    // 107.5%
    const BORROW_OPENING_FEE: u128 = 500;           // 0.5%
    const INTEREST: u128 = 1000;                    // 1%
    const TOKEN_AMOUNT: u128 = 100 * 10000 * 1000 * 1000 * 1000;    // 1M

    public(script) fun initialize(account: signer) {
        WEN::mint_to(&account, Signer::address_of(&account), TOKEN_AMOUNT);
        LendingPool::initialize<STC_POOL, STC, WEN>(
            &account,
            COLLATERIZATION_RATE,
            LIQUIDATION_MULTIPLIER,
            BORROW_OPENING_FEE,
            INTEREST,
            TOKEN_AMOUNT,
            ORACLE_NAME,
        );
    }
    public(script) fun deposit(account: signer, amount: u128) {
        LendingPool::deposit<STC_POOL, WEN>(&account, amount);
    }

    // fee
    public(script) fun set_fee_to(account: signer, new_fee_to: address) {
        LendingPool::set_fee_to<STC_POOL>(&account, new_fee_to);
    }
    public(script) fun withdraw() { LendingPool::withdraw<STC_POOL, WEN>(); }
    public(script) fun accrue() { LendingPool::accrue<STC_POOL, WEN>(); }

    // oracle
    public(script) fun update_exchange_rate() { LendingPool::update_exchange_rate<STC_POOL>(); }
    public fun get_exchange_rate(): (u128, u128) { LendingPool::get_exchange_rate<STC_POOL>() }
    public fun latest_exchange_rate(): (u128, u128) { LendingPool::latest_exchange_rate<STC_POOL>() }

    // config
    public fun pool_info(): (u128, u128, u128, u128) { LendingPool::pool_info<STC_POOL>() }
    public fun settings(): (u128, u128, u128, u128, u128) {
        (
            COLLATERIZATION_RATE,
            COLLATERIZATION_RATE,
            LIQUIDATION_MULTIPLIER,
            BORROW_OPENING_FEE,
            INTEREST,
        )
    }
    public fun is_deprecated(): bool { LendingPool::is_deprecated<STC_POOL>() }
    public fun collateral_info(): u128 { LendingPool::collateral_info<STC_POOL, STC>() }
    // (part, amount, left)
    public fun borrow_info(): (u128, u128, u128) { LendingPool::borrow_info<STC_POOL, WEN>() }
    public fun fee_info(): (address, u128, u64) { LendingPool::fee_info<STC_POOL>() }
    public fun position(addr: address): (u128, u128, u128) {
        let (collateral, part) = LendingPool::position<STC_POOL>(addr);
        let amount = LendingPool::toAmount<STC_POOL, WEN>(part, true);
        (collateral, part, amount)
    }

    // collateral
    public(script) fun add_collateral(account: signer, amount: u128) {
        LendingPool::add_collateral<STC_POOL, STC>(&account, amount);
    }
    public(script) fun remove_collateral(account: signer, receiver: address, amount: u128) {
        LendingPool::remove_collateral<STC_POOL, STC, WEN>(&account, receiver, amount);
    }

    // borrow
    public(script) fun borrow(account: signer, receiver: address, amount: u128) {
        LendingPool::borrow<STC_POOL, WEN>(&account, receiver, amount);
    }
    public(script) fun repay(account: signer, receiver: address, part: u128) {
        LendingPool::repay<STC_POOL, WEN>(&account, receiver, part);
    }

    // liquidate
    public fun is_solvent(addr: address, exchange_rate: u128): bool {
        LendingPool::is_solvent<STC_POOL, WEN>(addr, exchange_rate)
    }
    public(script) fun liquidate(
        account: signer,
        users: vector<address>,
        max_parts: vector<u128>,
        to: address,
    ) {
        LendingPool::liquidate<STC_POOL, STC, WEN>(&account, &users, &max_parts, to);
    }

    // cook
    public(script) fun cook(
        account: signer,
        actions: vector<u8>,
        collateral_amount: u128,
        remove_collateral_amount: u128,
        remove_collateral_to: address,
        borrow_amount: u128,
        borrow_to: address,
        repay_part: u128,
        repay_to: address
    ) {
        LendingPool::cook<STC_POOL, STC, WEN>(
            &account,
            &actions,
            collateral_amount,
            remove_collateral_amount,
            remove_collateral_to,
            borrow_amount,
            borrow_to,
            repay_part,
            repay_to,
        );
    }

    // deprecated
    public(script) fun deprecated(
        account: signer,
        to: address,
        collateral_amount: u128,
        borrow_amount: u128,
    ) {
        LendingPool::deprecated<STC_POOL, STC, WEN>(&account, to, collateral_amount, borrow_amount);
    }
}
}
