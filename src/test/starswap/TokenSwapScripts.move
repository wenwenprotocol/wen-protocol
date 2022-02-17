// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x300000 {
module TokenSwapScripts {
    use 0x300000::TokenSwapLibrary;
    use 0x300000::TokenSwapRouter;

    /// register swap for admin user
    public(script) fun register_swap_pair<X: copy + drop + store,
                                          Y: copy + drop + store>(account: signer) {
        TokenSwapRouter::register_swap_pair<X, Y>(&account);
    }

    /// Add liquidity for user
    public(script) fun add_liquidity<X: copy + drop + store,
                                     Y: copy + drop + store>(
        signer: signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128) {
        TokenSwapRouter::add_liquidity<X, Y>(
            &signer,
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min);
    }

    /// Remove liquidity for user
    public(script) fun remove_liquidity<X: copy + drop + store,
                                        Y: copy + drop + store>(
        signer: signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        TokenSwapRouter::remove_liquidity<X, Y>(
            &signer, liquidity, amount_x_min, amount_y_min);
    }

    /// Poundage number of liquidity token pair
    public(script) fun get_poundage_rate<X: copy + drop + store,
                                         Y: copy + drop + store>(): (u64, u64) {
        TokenSwapRouter::get_poundage_rate<X, Y>()
    }

    public(script) fun swap_exact_token_for_token<X: copy + drop + store,
                                                  Y: copy + drop + store>(
        signer: signer,
        amount_x_in: u128,
        amount_y_out_min: u128,
    ) {
        TokenSwapRouter::swap_exact_token_for_token<X, Y>(&signer, amount_x_in, amount_y_out_min);
    }

    public(script) fun swap_token_for_exact_token<X: copy + drop + store,
                                                  Y: copy + drop + store>(
        signer: signer,
        amount_x_in_max: u128,
        amount_y_out: u128,
    ) {
        TokenSwapRouter::swap_token_for_exact_token<X, Y>(&signer, amount_x_in_max, amount_y_out);
    }

    /// Poundage rate from swap fee
    public(script) fun set_poundage_rate<X: copy + drop + store,
                                         Y: copy + drop + store>(signer: signer, num: u64, denum: u64) {
        TokenSwapRouter::set_poundage_rate<X, Y>(&signer, num, denum);
    }

    /// Operation rate from all swap fee
    public(script) fun set_swap_fee_operation_rate(signer: signer, num: u64, denum: u64) {
        TokenSwapRouter::set_swap_fee_operation_rate(&signer, num, denum);
    }

    /// Get amount in with token pair pondage rate
    public fun get_amount_in<X: copy + drop + store,
                             Y: copy + drop + store>(x_value: u128): u128 {
        let (reserve_x, reverse_y) = TokenSwapRouter::get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = TokenSwapRouter::get_poundage_rate<X, Y>();
        TokenSwapLibrary::get_amount_in(x_value, reserve_x, reverse_y, fee_numberator, fee_denumerator)
    }

    /// Get amount out with token pair pondage rate
    public fun get_amount_out<X: copy + drop + store,
                              Y: copy + drop + store>(x_in_value: u128): u128 {
        let (reserve_x, reverse_y) = TokenSwapRouter::get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = TokenSwapRouter::get_poundage_rate<X, Y>();
        TokenSwapLibrary::get_amount_out(x_in_value, reserve_x, reverse_y, fee_numberator, fee_denumerator)
    }

}
}
