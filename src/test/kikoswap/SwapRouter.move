address 0x400000 {
module SwapRouter {
    use 0x1::Signer;
    use 0x400000::SwapLibrary;
    use 0x400000::SwapPair;

    const CONFIG_ADDRESS: address = @0x400000;
    const PAIR_ADDRESS: address = @0x400000;

    const SWAP_PAIR_NOT_EXISTS: u64 = 100001;
    const INSUFFICIENT_X_AMOUNT: u64 = 100002;
    const INSUFFICIENT_Y_AMOUNT: u64 = 100003;
    const EXCESSIVE_X_DESIRED: u64 = 100004;
    const INSUFFICIENT_OUTPUT_AMOUNT: u64 = 100005;
    const EXCESSIVE_INPUT_AMOUNT: u64 = 100006;

    // **** ADD LIQUDITY ****
    public fun f_add_liquidity<X: store, Y: store>(
        signer: &signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128
    ): (u128, u128) {
        let pair_exists = SwapPair::pair_exists<X, Y>(PAIR_ADDRESS);
        if (!pair_exists) {
            // admin can create swap pair
            assert(Signer::address_of(signer) == PAIR_ADDRESS, SWAP_PAIR_NOT_EXISTS);
            SwapPair::create_pair<X, Y>(signer);
        };

        let (reserve_x, reserve_y) = SwapPair::get_reserves<X, Y>();
    
        let (amount_x, amount_y);
        if (reserve_x == 0 && reserve_y == 0) {
            (amount_x, amount_y) = (amount_x_desired, amount_y_desired);
        } else {
            let amount_y_optimal = SwapLibrary::quote(amount_x_desired, reserve_x, reserve_y);
            if (amount_y_optimal <= amount_y_desired) {
                assert(amount_y_optimal >= amount_y_min, INSUFFICIENT_Y_AMOUNT);
                (amount_x, amount_y) = (amount_x_desired, amount_y_optimal);
            } else {
                let amount_x_optimal = SwapLibrary::quote(amount_y_desired, reserve_y, reserve_x);
                assert(amount_x_optimal <= amount_x_desired, EXCESSIVE_X_DESIRED);
                assert(amount_x_optimal >= amount_x_min, INSUFFICIENT_X_AMOUNT);
                (amount_x, amount_y) = (amount_x_optimal, amount_y_desired);
            };
        };
        (amount_x, amount_y)
    }

    // add liquidity
    public fun add_liquidity<X: store, Y: store>(
        signer: &signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128
    ) {
        // order x and y to avoid duplicates
        let order = SwapLibrary::get_token_order<X, Y>();
        if (order == 1) {
            // calculate the amount of x and y
            let (amount_x, amount_y) = f_add_liquidity<X, Y>(signer, amount_x_desired, amount_y_desired, amount_x_min, amount_y_min);
            // add liquidity with amount
            SwapPair::mint<X, Y>(signer, amount_x, amount_y);
        } else {
            let (amount_y, amount_x) = f_add_liquidity<Y, X>(signer, amount_y_desired, amount_x_desired, amount_y_min, amount_x_min);
            SwapPair::mint<Y, X>(signer, amount_y, amount_x);
        };
    }

    // **** REMOVE LIQUDITY ****

    // remove liquidity
    public fun remove_liquidity<X: store, Y: store>(
        signer: &signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128
    ) {
        let order = SwapLibrary::get_token_order<X, Y>();
        let (amount_x, amount_y);
        if (order == 1) {
            (amount_x, amount_y) = SwapPair::burn<X, Y>(signer, liquidity);
        } else {
            (amount_y, amount_x) = SwapPair::burn<Y, X>(signer, liquidity);
        };
        assert(amount_x >= amount_x_min, INSUFFICIENT_X_AMOUNT);
        assert(amount_y >= amount_y_min, INSUFFICIENT_Y_AMOUNT);
    }

    // **** SWAP EXACT TOKEN FOR TOKEN ****
    fun f_swap_exact_token_for_token<X: store, Y: store>(
        signer: &signer, 
        amount_x_in: u128,
        amount_y_in: u128,
        amount_x_out_min: u128,
        amount_y_out_min: u128
    ): u128 {
        let amount_out;
        if (amount_x_in > 0) {
            // x swap y
            let (reserve_x, reserve_y) = SwapPair::get_reserves<X, Y>();
            let amount_y_out = SwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y);
            assert(amount_y_out >= amount_y_out_min, INSUFFICIENT_OUTPUT_AMOUNT);
            SwapPair::swap<X, Y>(signer, amount_x_in, 0u128, 0u128, amount_y_out);
            amount_out = amount_y_out;
        } else {
            // y swap x
            let (reserve_x, reserve_y) = SwapPair::get_reserves<X, Y>();
            let amount_x_out = SwapLibrary::get_amount_out(amount_y_in, reserve_y, reserve_x);
            assert(amount_x_out >= amount_x_out_min, INSUFFICIENT_OUTPUT_AMOUNT);
            SwapPair::swap<X, Y>(signer, 0u128, amount_y_in, amount_x_out, 0u128);
            amount_out = amount_x_out;
        };
        amount_out
    }

    // swap exact x for y
    // Specify the number of tokens to sell and buy another token
    public fun swap_exact_token_for_token<X: store, Y: store>(
        signer: &signer,
        amount_x_in: u128,
        amount_y_out_min: u128
    ): u128 {
        SwapLibrary::accept_token<Y>(signer);
        let order = SwapLibrary::get_token_order<X, Y>();
        let result;
        if (order == 1) {
            result = f_swap_exact_token_for_token<X, Y>(signer, amount_x_in, 0u128, 0u128, amount_y_out_min);
        } else {
            result = f_swap_exact_token_for_token<Y, X>(signer, 0u128, amount_x_in, amount_y_out_min, 0u128);
        };
        result
    }

    // **** SWAP TOKEN FOR EXACT TOKEN ****
    
    fun f_swap_token_for_exact_token<X: store, Y: store>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_in_max: u128,
        amount_x_out: u128,
        amount_y_out: u128
    ) {
        if (amount_x_out > 0) {
            // y swap x
            let (reserve_x, reserve_y) = SwapPair::get_reserves<X, Y>();
            let amount_y_in = SwapLibrary::get_amount_in(amount_x_out, reserve_y, reserve_x);
            assert(amount_y_in <= amount_y_in_max, EXCESSIVE_INPUT_AMOUNT);
            SwapPair::swap<X, Y>(signer, 0u128, amount_y_in, amount_x_out, 0u128);
        } else {
            // x swap y
            let (reserve_x, reserve_y) = SwapPair::get_reserves<X, Y>();
            let amount_x_in = SwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y);
            assert(amount_x_in <= amount_x_in_max, EXCESSIVE_INPUT_AMOUNT);
            SwapPair::swap<X, Y>(signer, amount_x_in, 0u128, 0u128, amount_y_out);
        };
    }

    // swap x for exact y
    // Specify the number of tokens to buy and sell another token
    public fun swap_token_for_exact_token<X: store, Y: store>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_out: u128
    ) {
        SwapLibrary::accept_token<Y>(signer);
        let order = SwapLibrary::get_token_order<X, Y>();
        if (order == 1) {
            f_swap_token_for_exact_token<X, Y>(signer, amount_x_in_max, 0u128, 0u128, amount_y_out);
        } else {
            f_swap_token_for_exact_token<Y, X>(signer, 0u128, amount_x_in_max, amount_y_out, 0u128);
        };
    }

}
}
