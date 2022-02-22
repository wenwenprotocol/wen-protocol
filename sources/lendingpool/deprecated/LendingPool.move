address WenProtocol {
module LendingPool {
    use StarcoinFramework::Token::{Self,Token};
    use StarcoinFramework::Event;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Timestamp;

    use WenProtocol::Rebase;
    use WenProtocol::SafeMath;
    use WenProtocol::PoolOracle;

    // config
    // liquidate * 10% -> fees_earned
    const DISTRIBUTION_PART: u128 = 10;
    const DISTRIBUTION_PRECISION: u128 = 100;
    // borrow_opening_fee = 1000  => 1%
    const BORROW_OPENING_FEE_PRECISION: u128 = 100 * 1000;
    // liquidation_multiplier = 105000 => 105%
    const LIQUIDATION_MULTIPLIER_PRECISION: u128 = 100 * 1000;
    // collaterization_rate = 90000 => 90%
    const COLLATERIZATION_RATE_PRECISION: u128 = 100 * 1000;
    // 1e18
    const INTEREST_PRECISION: u128 = 1000000000000000000;
    // 2.5 * (1e18 /365.25 * 3600 * 24 /100 ) => 2.5%
    // interest_per_second = 2500 => 2.5%
    const INTEREST_CONVERSION: u128 = 365250 * 3600 * 24 * 100;
    // EXCHANGE_RATE_PRECISION == PoolOracle.PRECISION
    const EXCHANGE_RATE_PRECISION: u128 = 1000000 * 1000000;

    struct AccrueEvent has drop, store { amount: u128 }
    struct FeeToEvent has drop, store { fee_to: address }

    struct PoolInfo<phantom PoolType> has key, store {
        collaterization_rate: u128,
        liquidation_multiplier: u128,
        borrow_opening_fee: u128,
        interest_per_second: u128,
        fee_to: address,
        fees_earned: u128,
        last_accrued: u64,
        fee_to_events: Event::EventHandle<FeeToEvent>,
        accrue_events: Event::EventHandle<AccrueEvent>,
        deprecated: bool,
    }

    // Collateral
    struct RemoveCollateralEvent has drop, store { from: address, to: address, amount: u128 }
    struct AddCollateralEvent has drop, store { account: address, amount: u128 }
    struct LiquidateCollateralEvent has drop, store { account: address, amount: u128 }
    struct TotalCollateral<phantom PoolType, phantom CollateralTokenType> has key, store {
        balance: Token<CollateralTokenType>,    // user deposited
        add_events: Event::EventHandle<AddCollateralEvent>,
        remove_events: Event::EventHandle<RemoveCollateralEvent>,
        liquidate_events: Event::EventHandle<LiquidateCollateralEvent>,
    }

    // borrow
    struct BorrowEvent has drop, store { from: address, to: address, amount: u128, part: u128 }
    struct RepayEvent has drop, store { from: address, to: address, amount: u128, part: u128 }
    struct LiquidateEvent has drop, store { account: address, amount: u128 }
    struct DepositEvent has drop, store { account: address, amount: u128 }
    struct WithdrawEvent has drop, store { account: address, amount: u128 }
    struct TotalBorrow<phantom PoolType, phantom BorrowTokenType> has key, store {
        balance: Token<BorrowTokenType>,    // left to borrow
        borrow_events: Event::EventHandle<BorrowEvent>,
        repay_events: Event::EventHandle<RepayEvent>,
        liquidate_events: Event::EventHandle<LiquidateEvent>,
        withdraw_events: Event::EventHandle<WithdrawEvent>,
        deposit_events: Event::EventHandle<DepositEvent>,
    }

    // user position
    struct Position<phantom PoolType> has key, store { collateral: u128, borrow: u128 }

    // error code
    const ERR_ALREADY_DEPRECATED: u64 = 100;
    const ERR_NOT_AUTHORIZED: u64 = 101;
    const ERR_USER_INSOLVENT: u64 = 102;
    const ERR_ACCEPT_TOKEN: u64 = 103;
    const ERR_LENGTH_NOT_EQUAL: u64 = 104;
    const ERR_EMPTY: u64 = 105;

    const ERR_NOT_EXIST: u64 = 111;
    const ERR_BORROW_NOT_EXIST: u64 = 112;

    const ERR_ZERO_AMOUNT: u64 = 121;
    const ERR_TOO_BIG_AMOUNT: u64 = 122;

    // cap
    struct SharedRebaseModifyCapability<phantom T> has key, store { cap: Rebase::ModifyCapability<T> }

    // =================== private fun ===================
    // get T issuer
    fun t_address<T: store>(): address { Token::token_address<T>() }

    fun assert_owner<T: store>(account: &signer): address {
        let owner = t_address<T>();
        assert!(Signer::address_of(account) == owner, ERR_NOT_AUTHORIZED);
        owner
    }

    fun assert_total_borrow<PoolType: store, BorrowTokenType: store>(): address {
        let pool_owner = t_address<PoolType>();
        assert!(exists<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner), ERR_NOT_EXIST);
        pool_owner
    }

    fun assert_total_collateral<PoolType: store, CollateralTokenType: store>(): address {
        let pool_owner = t_address<PoolType>();
        assert!(exists<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner), ERR_NOT_EXIST);
        pool_owner
    }

    // =================== initialize ===================
    // only PoolType issuer can initialize
    public fun initialize<PoolType: store, CollateralTokenType: store, BorrowTokenType: store>(
        account: &signer,
        collaterization_rate: u128,
        liquidation_multiplier: u128,
        borrow_opening_fee: u128,
        interest_per_second: u128,
        amount: u128,
        oracle_name: vector<u8>,
    ) acquires TotalBorrow {
        let owner = assert_owner<PoolType>(account);

        // init PoolInfo
        move_to(
            account,
            PoolInfo<PoolType> {
                collaterization_rate: collaterization_rate,
                liquidation_multiplier: liquidation_multiplier,
                borrow_opening_fee: borrow_opening_fee,
                interest_per_second: interest_per_second,
                fee_to: owner,
                fees_earned: 0,
                last_accrued: Timestamp::now_seconds(),
                accrue_events: Event::new_event_handle<AccrueEvent>(account),
                fee_to_events: Event::new_event_handle<FeeToEvent>(account),
                deprecated: false,
            },
        );

        // init collateral
        move_to(
            account,
            TotalCollateral<PoolType, CollateralTokenType> {
                balance: Token::zero<CollateralTokenType>(),
                add_events: Event::new_event_handle<AddCollateralEvent>(account),
                remove_events: Event::new_event_handle<RemoveCollateralEvent>(account),
                liquidate_events: Event::new_event_handle<LiquidateCollateralEvent>(account),
            },
        );

        // init borrow
        move_to(
            account,
            TotalBorrow<PoolType, BorrowTokenType> {
                balance: Token::zero<BorrowTokenType>(),
                borrow_events: Event::new_event_handle<BorrowEvent>(account),
                repay_events: Event::new_event_handle<RepayEvent>(account),
                liquidate_events: Event::new_event_handle<LiquidateEvent>(account),
                withdraw_events: Event::new_event_handle<WithdrawEvent>(account),
                deposit_events: Event::new_event_handle<DepositEvent>(account)
            },
        );
        Rebase::initialize<TotalBorrow<PoolType, BorrowTokenType>>(account);
        move_to(
            account,
            SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>> {
                cap: Rebase::remove_modify_capability<TotalBorrow<PoolType, BorrowTokenType>>(account),
            },
        );

        // deposit borrow token
        if (amount > 0) {
            deposit<PoolType, BorrowTokenType>(account, amount);
        };

        // oracle
        PoolOracle::register<PoolType>(account, oracle_name);
    }

    // =================== borrowToken deposit and withdraw ===================
    // deposit borrowToken
    public fun deposit<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        amount: u128,
    ) acquires TotalBorrow {
        assert_owner<PoolType>(account);
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        assert!(amount > 0, ERR_ZERO_AMOUNT);

        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        Token::deposit(&mut total_borrow.balance, Account::withdraw<BorrowTokenType>(account, amount));
        Event::emit_event(
            &mut total_borrow.deposit_events,
            DepositEvent {
                account: Signer::address_of(account),
                amount: amount,
            },
        );
    }

    public fun withdraw<PoolType: store, BorrowTokenType: store>()
    acquires SharedRebaseModifyCapability, PoolInfo, TotalBorrow {
        accrue<PoolType, BorrowTokenType>();
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        let to = info.fee_to;
        let fees = info.fees_earned;
        assert!(Account::is_accepts_token<BorrowTokenType>(to), ERR_ACCEPT_TOKEN);
        assert!(fees > 0, ERR_ZERO_AMOUNT);

        // transfer borrow token
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        Account::deposit(to, Token::withdraw(&mut total_borrow.balance, fees));
        Event::emit_event(
            &mut total_borrow.withdraw_events,
            WithdrawEvent { account: to, amount: fees },
        );

        // Affect info
        info.fees_earned = 0;
        Event::emit_event(&mut info.accrue_events, AccrueEvent { amount: 0 });
    }

    // =================== oracle ===================
    // Gets the exchange rate. I.e how much collateral to buy 1 asset.
    public fun update_exchange_rate<PoolType: store>(): u128 {
        let (exchange_rate, _) = PoolOracle::update<PoolType>();
        exchange_rate
    }

    // =================== tools fun ===================
    // get user's position (collateral, borrowed part)
    public fun position<PoolType: store>(addr: address): (u128, u128) acquires Position {
        if (!exists<Position<PoolType>>(addr)) {
            (0u128, 0u128)
        } else {
            let user_info = borrow_global<Position<PoolType>>(addr);
            (user_info.collateral, user_info.borrow)
        }
    }

    public fun get_exchange_rate<PoolType: store>(): (u128, u128) {
        let (exchange_rate, _, _) = PoolOracle::get<PoolType>();
        (exchange_rate, EXCHANGE_RATE_PRECISION)
    }

    public fun latest_exchange_rate<PoolType: store>(): (u128, u128) {
        PoolOracle::latest_exchange_rate<PoolType>()
    }

    // return base config (Maximum collateral ratio, Liquidation fee, Borrow fee, Interest)
    public fun pool_info<PoolType: store>(): (u128, u128, u128, u128) acquires PoolInfo {
        let info = borrow_global<PoolInfo<PoolType>>(t_address<PoolType>());
        (
            info.collaterization_rate,
            info.liquidation_multiplier,
            info.borrow_opening_fee,
            info.interest_per_second,
        )
    }

    public fun is_deprecated<PoolType: store>(): bool acquires PoolInfo {
        borrow_global<PoolInfo<PoolType>>(t_address<PoolType>()).deprecated
    }

    // return collateral deposited amount
    public fun collateral_info<PoolType: store, CollateralTokenType: store>(): u128 acquires TotalCollateral {
        let pool_owner = assert_total_collateral<PoolType, CollateralTokenType>();
        let total_collateral = borrow_global<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);
        Token::value(&total_collateral.balance)
    }

    // return borrow info (total borrowed part, total borrowed amount, left to borrow)
    public fun borrow_info<PoolType: store, BorrowTokenType: store>(): (u128, u128, u128) acquires TotalBorrow {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let total_borrow = borrow_global<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        let (elastic, base) = Rebase::get<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        (base, elastic, Token::value(&total_borrow.balance))
    }

    public fun set_fee_to<PoolType: store>(account: &signer, new_fee_to: address) acquires PoolInfo {
        let owner = assert_owner<PoolType>(account);
        let info = borrow_global_mut<PoolInfo<PoolType>>(owner);
        // Affect fee_to
        info.fee_to = new_fee_to;
        Event::emit_event(&mut info.fee_to_events, FeeToEvent { fee_to: new_fee_to });
    }

    // return fee config (Maximum collateral ratio, Liquidation fee, Borrow fee, Interest)
    public fun fee_info<PoolType: store>(): (address, u128, u64) acquires PoolInfo {
        let info = borrow_global<PoolInfo<PoolType>>(t_address<PoolType>());
        (
            info.fee_to,
            info.fees_earned,
            info.last_accrued,
        )
    }

    // part <=> amount
    public fun toAmount<PoolType: store, BorrowTokenType: store>(part: u128, roundUp: bool): u128 {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, part, roundUp)
    }

    public fun toPart<PoolType: store, BorrowTokenType: store>(amount: u128, roundUp: bool): u128 {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        Rebase::toBase<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, amount, roundUp)
    }

    // =================== accumulation of fees ===================
    // Accrues the interest on the borrowed tokens and handles the accumulation of fees.
    public fun accrue<PoolType: store, BorrowTokenType: store>() acquires SharedRebaseModifyCapability, PoolInfo {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        assert!(exists<PoolInfo<PoolType>>(pool_owner), ERR_NOT_EXIST);

        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        let elapsedTime = ((Timestamp::now_seconds() - info.last_accrued) as u128);
        if (elapsedTime == 0) {
            return
        };
        info.last_accrued = Timestamp::now_seconds();

        let (elastic, base) = Rebase::get<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        if (base == 0) {
            return
        };

        // Accrue interest
        let interest = SafeMath::safe_mul_div(info.interest_per_second, INTEREST_PRECISION, INTEREST_CONVERSION);
        let amount = SafeMath::safe_mul_div(elastic, interest * elapsedTime, INTEREST_PRECISION);

        // Affect elastic
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        Rebase::addElasticWithCapability<TotalBorrow<PoolType, BorrowTokenType>>(&cap.cap, amount);

        // Affect fee
        info.fees_earned = info.fees_earned + amount;
        Event::emit_event(&mut info.accrue_events, AccrueEvent { amount });
    }

    // =================== user solvent ===================
    // Concrete implementation of `is_solvent`. Includes a third parameter to allow caching `exchange_rate`.
    // exchange_rate The exchange rate. Used to cache the `exchange_rate` between calls.
    public fun is_solvent<PoolType: store, BorrowTokenType: store>(
        addr: address,
        exchange_rate: u128,
    ): bool acquires PoolInfo, Position {
        // accrue must have already been called!
        // user have no Collateral and borrow
        if (!exists<Position<PoolType>>(addr)) {
            return true
        };
        let user_info = borrow_global<Position<PoolType>>(addr);
        if (user_info.borrow == 0) { return true };
        if (user_info.collateral == 0) { return false };

        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let info = borrow_global<PoolInfo<PoolType>>(pool_owner);
        // user_total_collateral = user_info.collateral * (EXCHANGE_RATE_PRECISION * info.collaterization_rate / COLLATERIZATION_RATE_PRECISION)
        // user_total_borrow = Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, user_info.borrow, true) * exchange_rate
        // user_total_collateral >= user_total_borrow
        SafeMath::safe_more_than_or_equal(
            user_info.collateral,
            EXCHANGE_RATE_PRECISION * info.collaterization_rate / COLLATERIZATION_RATE_PRECISION,
            Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, user_info.borrow, true),
            exchange_rate,
        )
    }

    // Checks if the user is solvent in the closed liquidation case at the end of the function body
    fun assert_is_solvent<PoolType: store, BorrowTokenType: store>(addr: address) acquires PoolInfo, Position {
        // let (exchange_rate, _, _) = PoolOracle::get<PoolType>();
        let (exchange_rate, _) = latest_exchange_rate<PoolType>();
        assert!(is_solvent<PoolType, BorrowTokenType>(addr, exchange_rate), ERR_USER_INSOLVENT);
    }

    // =================== add collateral ===================
    // Adds `collateral` to the account
    public fun add_collateral<PoolType: store, CollateralTokenType: store>(
        account: &signer,
        amount: u128,
    ) acquires TotalCollateral, Position, PoolInfo {
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        let account_addr = Signer::address_of(account);
        let pool_owner = assert_total_collateral<PoolType, CollateralTokenType>();

        let info = borrow_global<PoolInfo<PoolType>>(pool_owner);
        assert!(!info.deprecated, ERR_ALREADY_DEPRECATED);

        // Affect TotalCollateral
        let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);
        Token::deposit(&mut total_collateral.balance, Account::withdraw<CollateralTokenType>(account, amount));
        Event::emit_event(
            &mut total_collateral.add_events,
            AddCollateralEvent {
                account: Signer::address_of(account),
                amount: amount,
            },
        );

        // Affect user info
        if (!exists<Position<PoolType>>(account_addr)) {
            move_to(account, Position<PoolType> { collateral: amount, borrow: 0 });
        } else {
            let user_info = borrow_global_mut<Position<PoolType>>(account_addr);
            user_info.collateral = user_info.collateral + amount;
        };
    }

    // =================== remove collateral ===================
    // Removes `amount` amount of collateral and transfers it to `receiver`.
    public fun remove_collateral<PoolType: store, CollateralTokenType: store, BorrowTokenType: store>(
        account: &signer,
        receiver: address,
        amount: u128,
    ) acquires SharedRebaseModifyCapability, PoolInfo, TotalCollateral, Position {
        let account_addr = Signer::address_of(account);
        // accrue must be called because we check solvency
        accrue<PoolType, BorrowTokenType>();
        do_remove_collateral<PoolType, CollateralTokenType>(account_addr, receiver, amount);
        assert_is_solvent<PoolType, BorrowTokenType>(account_addr);
    }

    fun do_remove_collateral<PoolType: store, CollateralTokenType: store>(
        from: address,
        to: address,
        amount: u128,
    ) acquires TotalCollateral, Position {
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        assert!(exists<Position<PoolType>>(from), ERR_NOT_EXIST);
        let user_info = borrow_global_mut<Position<PoolType>>(from);
        assert!(amount <= user_info.collateral, ERR_TOO_BIG_AMOUNT);
        assert!(Account::is_accepts_token<CollateralTokenType>(to), ERR_ACCEPT_TOKEN);

        let pool_owner = assert_total_collateral<PoolType, CollateralTokenType>();
        let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);

        // Affect user info
        user_info.collateral = user_info.collateral - amount;
        if (user_info.collateral == 0 && user_info.borrow == 0) {
            let Position<PoolType> {collateral: _, borrow: _} = move_from<Position<PoolType>>(from);
        };

        // transfer collateral
        Account::deposit(to, Token::withdraw(&mut total_collateral.balance, amount));
        Event::emit_event(
            &mut total_collateral.remove_events,
            RemoveCollateralEvent { from: from, to: to, amount: amount },
        );
    }

    // =================== borrow ===================
    // Sender borrows `amount` and transfers it to `receiver`.
    public fun borrow<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        receiver: address,
        amount: u128,
    ): u128 acquires SharedRebaseModifyCapability, PoolInfo, TotalBorrow, Position {
        // accrue must be called because we check solvency
        accrue<PoolType, BorrowTokenType>();
        let part = do_borrow<PoolType, BorrowTokenType>(account, receiver, amount);
        assert_is_solvent<PoolType, BorrowTokenType>(Signer::address_of(account));
        part
    }

    fun do_borrow<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        to: address,
        amount: u128,
    ): u128 acquires SharedRebaseModifyCapability, TotalBorrow, PoolInfo, Position {
        let from = Signer::address_of(account);
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        // add_collateral will move_to<Position>
        assert!(exists<Position<PoolType>>(from), ERR_NOT_EXIST);
        if (!Account::is_accepts_token<BorrowTokenType>(to)) {
            if (from == to) {
                Account::do_accept_token<BorrowTokenType>(account);
            } else {
                assert!(false, ERR_ACCEPT_TOKEN);
            };
        };

        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        assert!(amount <= Token::value(&total_borrow.balance), ERR_TOO_BIG_AMOUNT);

        // borrow fee
        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        assert!(!info.deprecated, ERR_ALREADY_DEPRECATED);
        let fee_amount = SafeMath::safe_mul_div(amount, info.borrow_opening_fee, BORROW_OPENING_FEE_PRECISION);

        // Affect total borrow
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        let part = Rebase::addByElasticWithCapability(&cap.cap, amount + fee_amount, true);

        // Affect accrue info
        info.fees_earned = info.fees_earned + fee_amount;
        Event::emit_event(&mut info.accrue_events, AccrueEvent { amount: fee_amount });

        // Affect user position
        let position = borrow_global_mut<Position<PoolType>>(from);
        position.borrow = position.borrow + part;

        // Affect borrow
        Account::deposit(to, Token::withdraw(&mut total_borrow.balance, amount));
        Event::emit_event(
            &mut total_borrow.borrow_events,
            BorrowEvent { from: from, to: to, amount: amount, part: part },
        );
        part
    }

    // =================== repay ===================
    // Repays a loan
    public fun repay<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        receiver: address,
        part: u128,
    ): u128 acquires SharedRebaseModifyCapability, PoolInfo, TotalBorrow, Position {
        // accrue must be called because we check solvency
        accrue<PoolType, BorrowTokenType>();
        do_repay<PoolType, BorrowTokenType>(account, receiver, part)
    }

    fun do_repay<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        to: address,
        part: u128,
    ): u128 acquires SharedRebaseModifyCapability, TotalBorrow, Position {
        assert!(part > 0, ERR_ZERO_AMOUNT);
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let position = borrow_global_mut<Position<PoolType>>(to);
        assert!(part <= position.borrow, ERR_TOO_BIG_AMOUNT);

        // Affect total borrow
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        let amount = Rebase::subByBaseWithCapability(&cap.cap, part, true);

        // Affect user position
        position.borrow = position.borrow - part;

        // Affect borrow token
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        Token::deposit(&mut total_borrow.balance, Account::withdraw<BorrowTokenType>(account, amount));
        Event::emit_event(
            &mut total_borrow.repay_events,
            RepayEvent { from: Signer::address_of(account), to: to, amount: amount, part: part },
        );
        amount
    }

    // =================== liquidate ===================
    // only script function
    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    // @param users An array of user addresses.
    // @param max_parts A one-to-one mapping to `users`, contains maximum (partial) borrow amounts (to liquidate) of the respective user.
    // @param to Address of the receiver in open liquidations.
    public fun liquidate<PoolType: store, CollateralTokenType: store, BorrowTokenType: store>(
        account: &signer,
        users: &vector<address>,
        max_parts: &vector<u128>,
        to: address,
    ) acquires SharedRebaseModifyCapability, PoolInfo, TotalCollateral, TotalBorrow, Position {
        let account_addr = Signer::address_of(account);
        let user_len = Vector::length<address>(users);
        assert!(user_len > 0, ERR_EMPTY);
        assert!(user_len == Vector::length<u128>(max_parts), ERR_LENGTH_NOT_EQUAL);
        if (!Account::is_accepts_token<CollateralTokenType>(to)) {
            if (account_addr == to) {
                Account::do_accept_token<BorrowTokenType>(account);
            } else {
                assert!(false, ERR_ACCEPT_TOKEN);
            };
        };

        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();

        // update exchange and accrue
        // let exchange_rate = update_exchange_rate<PoolType>();
        let (exchange_rate, _) = latest_exchange_rate<PoolType>();
        accrue<PoolType, BorrowTokenType>();

        let info = borrow_global<PoolInfo<PoolType>>(pool_owner);
        let liquidation_multiplier = info.liquidation_multiplier;
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);

        let allCollateral: u128 = 0;
        let allBorrowAmount: u128 = 0;
        let allBorrowPart: u128 = 0;
        let i = 0;
        while (i < user_len) {
            let addr = *Vector::borrow<address>(users, i);
            let max_part = *Vector::borrow<u128>(max_parts, i);
            if (!is_solvent<PoolType, BorrowTokenType>(addr, exchange_rate)) {

                // get borrow part
                let position = borrow_global_mut<Position<PoolType>>(addr);
                let part = position.borrow;
                if (max_part < position.borrow) { part = max_part; };

                // get borrow amount
                let amount = Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, part, false);

                // get collateral
                //amount.mul(LIQUIDATION_MULTIPLIER).mul(_exchangeRate) / (LIQUIDATION_MULTIPLIER_PRECISION*EXCHANGE_RATE_PRECISION)
                let collateral = SafeMath::safe_mul_div(
                    amount,
                    liquidation_multiplier * exchange_rate,
                    LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION,
                );

                // Affect position
                position.borrow = position.borrow - part;
                position.collateral = position.collateral - collateral;
                Event::emit_event(
                    &mut total_borrow.repay_events,
                    RepayEvent { from: account_addr, to: addr, amount: amount, part: part },
                );
                Event::emit_event(
                    &mut total_collateral.remove_events,
                    RemoveCollateralEvent { from: addr, to: to, amount: collateral },
                );

                // keeps total
                allCollateral = allCollateral + collateral;
                allBorrowAmount = allBorrowAmount + amount;
                allBorrowPart = allBorrowPart + part;
            };
            i = i + 1;
        };
        assert!(allBorrowAmount > 0, ERR_ZERO_AMOUNT);

        // Affect total botrrow
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        Rebase::subWithCapability(&cap.cap, allBorrowAmount, allBorrowPart);

        // Apply a percentual fee share to sShare holders ( must after `Affect total borrow`)
        // (allBorrowAmount.mul(LIQUIDATION_MULTIPLIER) / LIQUIDATION_MULTIPLIER_PRECISION).sub(allBorrowAmount).mul(DISTRIBUTION_PART) / DISTRIBUTION_PRECISION;
        let distribution_amount = SafeMath::safe_mul_div(
            SafeMath::safe_mul_div(
                allBorrowAmount,
                liquidation_multiplier,
                LIQUIDATION_MULTIPLIER_PRECISION,
            ) - allBorrowAmount,
            DISTRIBUTION_PART,
            DISTRIBUTION_PRECISION,
        );
        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        info.fees_earned = info.fees_earned + distribution_amount;
        Event::emit_event(&mut info.accrue_events, AccrueEvent { amount: distribution_amount });

        allBorrowAmount = allBorrowAmount + distribution_amount;

        // Affect tansfer collateral
        Account::deposit(to, Token::withdraw(&mut total_collateral.balance, allCollateral));

        // Affect tansfer
        Token::deposit(&mut total_borrow.balance, Account::withdraw<BorrowTokenType>(account, allBorrowAmount));
        Event::emit_event(
            &mut total_borrow.liquidate_events,
            LiquidateEvent { account: account_addr, amount: allBorrowAmount },
        );
    }

    // =================== cook ===================

    const ACTION_ADD_COLLATERAL: u8 = 1;
    const ACTION_REMOVE_COLLATERAL: u8 = 2;
    const ACTION_BORROW: u8 = 3;
    const ACTION_REPAY: u8 = 4;
    // address 0x0 = 0x00000000000000000000000000000000
    public fun cook<PoolType: store, CollateralTokenType: store, BorrowTokenType: store>(
        account: &signer,
        actions: &vector<u8>,
        collateral_amount: u128,
        remove_collateral_amount: u128,
        remove_collateral_to: address,
        borrow_amount: u128,
        borrow_to: address,
        repay_part: u128,
        repay_to: address,
    ) acquires SharedRebaseModifyCapability, PoolInfo, TotalCollateral, TotalBorrow, Position {
        // update exchange and accrue
        // update_exchange_rate<PoolType>();
        accrue<PoolType, BorrowTokenType>();

        let account_addr = Signer::address_of(account);
        let check_solvent = false;
        let len = Vector::length<u8>(actions);
        let i = 0;
        while (i < len) {
            let action = *Vector::borrow<u8>(actions, i);
            if (action == ACTION_ADD_COLLATERAL) {
                add_collateral<PoolType, CollateralTokenType>(account, collateral_amount);
            } else if (action == ACTION_REMOVE_COLLATERAL) {
                do_remove_collateral<PoolType, CollateralTokenType>(
                    account_addr,
                    remove_collateral_to,
                    remove_collateral_amount,
                );
                check_solvent = true;
            } else if (action == ACTION_BORROW) {
                do_borrow<PoolType, BorrowTokenType>(account, borrow_to, borrow_amount);
                check_solvent = true;
            } else if (action == ACTION_REPAY) {
                do_repay<PoolType, BorrowTokenType>(account, repay_to, repay_part);
            };
            i = i + 1;
        };
        if (check_solvent) {
            assert_is_solvent<PoolType, BorrowTokenType>(account_addr);
        };
    }

    // =================== deprecated ===================
    public fun deprecated<PoolType: store, CollateralTokenType: store, BorrowTokenType: store>(
        account: &signer,
        to: address,
        collateral_amount: u128,
        borrow_amount: u128,
    ) acquires PoolInfo, TotalBorrow, TotalCollateral {
        let owner = assert_owner<PoolType>(account);
        let info = borrow_global_mut<PoolInfo<PoolType>>(owner);

        // Affect deprecated
        info.deprecated = true;

        // Affect collateral
        if (collateral_amount > 0) {
            let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(owner);
            Account::deposit(to, Token::withdraw(&mut total_collateral.balance, collateral_amount));
        };

        // Affect borrow token
        if (borrow_amount > 0) {
            let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(owner);
            Account::deposit(to, Token::withdraw(&mut total_borrow.balance, borrow_amount));
        };
    }
 }
}
