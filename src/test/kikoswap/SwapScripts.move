address 0x400000 {
module SwapScripts {
    use 0x400000::SwapConfig;
    use 0x400000::SwapPair;
    use 0x400000::SwapRouter;
    use 0x400000::SwapLibrary;

    // **** CONFIG ****

    // init config only once
    public(script) fun init_config(
        sender: signer,
        fee_rate: u128,
        treasury_fee_rate: u128,
        extra0: u128,
        extra1: u128,
        extra2: u128,
        extra3: u128,
        extra4: u128
    ) {
        SwapConfig::initialize(
            &sender,
            fee_rate, 
            treasury_fee_rate,
            extra0, 
            extra1, 
            extra2, 
            extra3, 
            extra4
        );
    }

    // update config
    public(script) fun update_config(
        sender: signer,
        fee_rate: u128,
        treasury_fee_rate: u128,
        extra0: u128,
        extra1: u128,
        extra2: u128,
        extra3: u128,
        extra4: u128,
    ) {
        SwapConfig::update(
            &sender, 
            fee_rate, 
            treasury_fee_rate,
            extra0, 
            extra1, 
            extra2, 
            extra3, 
            extra4
        );
    }

    // **** TOKEN PAIR ****

    public(script) fun create_pair<X: store, Y: store>(sender: signer) {
        let order = SwapLibrary::get_token_order<X, Y>();
        if (order == 1) {
            SwapPair::create_pair<X, Y>(&sender);
        } else {
            SwapPair::create_pair<Y, X>(&sender);
        }
    }

    // **** LIQUDITY ****

    public(script) fun add_liquidity<X: store, Y: store>(
        sender: signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128
    ) {
        SwapRouter::add_liquidity<X, Y>(
            &sender,
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min
        );
    }

    public(script) fun remove_liquidity<X: store, Y: store>(
        sender: signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128
    ) {
        SwapRouter::remove_liquidity<X, Y>(
            &sender,
            liquidity,
            amount_x_min,
            amount_y_min
        );
    }

    // **** SWAP EXACT TOKEN FOR TOKEN ****

    // X -> Y
    public(script) fun swap_exact_token_for_token<X: store, Y: store>(
        sender: signer,
        amount_x_in: u128,
        amount_y_out_min: u128
    ) {
        SwapRouter::swap_exact_token_for_token<X, Y>(&sender, amount_x_in, amount_y_out_min);
    }

    // X -> X1 -> Y
    public(script) fun swap_exact_token_for_token_2<X: store, X1: store, Y: store>(
        sender: signer,
        amount_x_in: u128,
        amount_y_out_min: u128
    ) {
        let amount_x1_out = SwapRouter::swap_exact_token_for_token<X, X1>(&sender, amount_x_in, 0u128);
        SwapRouter::swap_exact_token_for_token<X1, Y>(&sender, amount_x1_out, amount_y_out_min);
    }

    // X -> X1 -> X2 -> Y
    public(script) fun swap_exact_token_for_token_3<X: store, X1: store, X2: store, Y: store>(
        sender: signer,
        amount_x_in: u128,
        amount_y_out_min: u128
    ) {
        let amount_x1_out = SwapRouter::swap_exact_token_for_token<X, X1>(&sender, amount_x_in, 0u128);
        let amount_x2_out = SwapRouter::swap_exact_token_for_token<X1, X2>(&sender, amount_x1_out, 0u128);
        SwapRouter::swap_exact_token_for_token<X2, Y>(&sender, amount_x2_out, amount_y_out_min);
    }

    // X -> X1 -> X2 -> X3 -> Y
    public(script) fun swap_exact_token_for_token_4<X: store, X1: store, X2: store, X3: store, Y: store>(
        sender: signer,
        amount_x_in: u128,
        amount_y_out_min: u128
    ) {
        let amount_x1_out = SwapRouter::swap_exact_token_for_token<X, X1>(&sender, amount_x_in, 0u128);
        let amount_x2_out = SwapRouter::swap_exact_token_for_token<X1, X2>(&sender, amount_x1_out, 0u128);
        let amount_x3_out = SwapRouter::swap_exact_token_for_token<X2, X3>(&sender, amount_x2_out, 0u128);
        SwapRouter::swap_exact_token_for_token<X3, Y>(&sender, amount_x3_out, amount_y_out_min);
    }

    // X -> X1 -> X2 -> X3 -> X4 -> Y
    public(script) fun swap_exact_token_for_token_5<X: store, X1: store, X2: store, X3: store, X4: store, Y: store>(
        sender: signer,
        amount_x_in: u128,
        amount_y_out_min: u128
    ) {
        let amount_x1_out = SwapRouter::swap_exact_token_for_token<X, X1>(&sender, amount_x_in, 0u128);
        let amount_x2_out = SwapRouter::swap_exact_token_for_token<X1, X2>(&sender, amount_x1_out, 0u128);
        let amount_x3_out = SwapRouter::swap_exact_token_for_token<X2, X3>(&sender, amount_x2_out, 0u128);
        let amount_x4_out = SwapRouter::swap_exact_token_for_token<X3, X4>(&sender, amount_x3_out, 0u128);
        SwapRouter::swap_exact_token_for_token<X4, Y>(&sender, amount_x4_out, amount_y_out_min);
    }

    // **** SWAP TOKEN FOR EXACT TOKEN ****

    // get amount_in without token order
    fun get_amount_in<X: store, Y: store>(amount_y_out: u128): u128{
        let order = SwapLibrary::get_token_order<X, Y>();
        if (order == 1) {
            let (reserve_x, reserve_y) = SwapPair::get_reserves<X, Y>();
            SwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y)
        } else {
            let (reserve_y, reserve_x) = SwapPair::get_reserves<Y, X>();
            SwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y)
        }
    }

    // X -> Y
    public(script) fun swap_token_for_exact_token<X: store, Y: store>(
        sender: signer,
        amount_x_in_max: u128,
        amount_y_out: u128
    ) {
        SwapRouter::swap_token_for_exact_token<X, Y>(&sender, amount_x_in_max, amount_y_out);
    }

    // X -> X1 -> Y
    public(script) fun swap_token_for_exact_token_2<X: store, X1: store, Y: store>(
        sender: signer,
        amount_x_in_max: u128,
        amount_y_out: u128
    ) {
        let amount_x1_in = get_amount_in<X1, Y>(amount_y_out);
        SwapRouter::swap_token_for_exact_token<X, X1>(&sender, amount_x_in_max, amount_x1_in);
        SwapRouter::swap_token_for_exact_token<X1, Y>(&sender, amount_x1_in, amount_y_out);
    }

    // X -> X1 -> X2 -> Y
    public(script) fun swap_token_for_exact_token_3<X: store, X1: store, X2: store, Y: store>(
        sender: signer,
        amount_x_in_max: u128,
        amount_y_out: u128
    ) {
        let amount_x2_in = get_amount_in<X2, Y>(amount_y_out);
        let amount_x1_in = get_amount_in<X1, X2>(amount_x2_in);
        SwapRouter::swap_token_for_exact_token<X, X1>(&sender, amount_x_in_max, amount_x1_in);
        SwapRouter::swap_token_for_exact_token<X1, X2>(&sender, amount_x1_in, amount_x2_in);
        SwapRouter::swap_token_for_exact_token<X2, Y>(&sender, amount_x2_in, amount_y_out);
    }

    // X -> X1 -> X2 -> X3 -> Y
    public(script) fun swap_token_for_exact_token_4<X: store, X1: store, X2: store, X3: store, Y: store>(
        sender: signer,
        amount_x_in_max: u128,
        amount_y_out: u128
    ) {
        let amount_x3_in = get_amount_in<X3, Y>(amount_y_out);
        let amount_x2_in = get_amount_in<X2, X3>(amount_x3_in);
        let amount_x1_in = get_amount_in<X1, X2>(amount_x2_in);
        SwapRouter::swap_token_for_exact_token<X, X1>(&sender, amount_x_in_max, amount_x1_in);
        SwapRouter::swap_token_for_exact_token<X1, X2>(&sender, amount_x1_in, amount_x2_in);
        SwapRouter::swap_token_for_exact_token<X2, X3>(&sender, amount_x2_in, amount_x3_in);
        SwapRouter::swap_token_for_exact_token<X3, Y>(&sender, amount_x3_in, amount_y_out);
    }

    // X -> X1 -> X2 -> X3 -> X4 -> Y
    public(script) fun swap_token_for_exact_token_5<X: store, X1: store, X2: store, X3: store, X4: store, Y: store>(
        sender: signer,
        amount_x_in_max: u128,
        amount_y_out: u128
    ) {
        let amount_x4_in = get_amount_in<X4, Y>(amount_y_out);
        let amount_x3_in = get_amount_in<X3, X4>(amount_x4_in);
        let amount_x2_in = get_amount_in<X2, X3>(amount_x3_in);
        let amount_x1_in = get_amount_in<X1, X2>(amount_x2_in);
        SwapRouter::swap_token_for_exact_token<X, X1>(&sender, amount_x_in_max, amount_x1_in);
        SwapRouter::swap_token_for_exact_token<X1, X2>(&sender, amount_x1_in, amount_x2_in);
        SwapRouter::swap_token_for_exact_token<X2, X3>(&sender, amount_x2_in, amount_x3_in);
        SwapRouter::swap_token_for_exact_token<X3, X4>(&sender, amount_x3_in, amount_x4_in);
        SwapRouter::swap_token_for_exact_token<X4, Y>(&sender, amount_x4_in, amount_y_out);
    }

}
}
