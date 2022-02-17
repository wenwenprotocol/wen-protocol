// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x100000 {
module TokenSwapLibrary {
    use 0x100000::StarswapSafeMath as SafeMath;

    const ERROR_ROUTER_PARAMETER_INVALID: u64 = 1001;
    const ERROR_SWAP_FEE_ALGORITHM_INVALID: u64 = 1002;

    /// Return amount_y needed to provide liquidity given `amount_x`
    public fun quote(amount_x: u128, reserve_x: u128, reserve_y: u128): u128 {
        assert(amount_x > 0, ERROR_ROUTER_PARAMETER_INVALID);
        assert(reserve_x > 0 && reserve_y > 0, ERROR_ROUTER_PARAMETER_INVALID);
        let amount_y = SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        amount_y
    }

    public fun get_amount_in(amount_out: u128,
                             reserve_in: u128,
                             reserve_out: u128,
                             fee_numerator: u64,
                             fee_denumerator: u64): u128 {
        assert(amount_out > 0, ERROR_ROUTER_PARAMETER_INVALID);
        assert(reserve_in > 0 && reserve_out > 0, ERROR_ROUTER_PARAMETER_INVALID);
        assert(fee_denumerator > 0 && fee_numerator > 0, ERROR_SWAP_FEE_ALGORITHM_INVALID);
        assert(fee_denumerator > fee_numerator, ERROR_SWAP_FEE_ALGORITHM_INVALID);

//        let denominator = (reserve_out - amount_out) * 997;
//        let r = SafeMath::safe_mul_div(amount_out * 1000, reserve_in, denominator);
//        r + 1

        let denominator = (reserve_out - amount_out) * ((fee_denumerator - fee_numerator) as u128);
        let r = SafeMath::safe_mul_div_u128(amount_out * (fee_denumerator as u128), reserve_in, denominator);
        r + 1
    }

    public fun get_amount_out(amount_in: u128,
                              reserve_in: u128,
                              reserve_out: u128,
                              fee_numerator: u64,
                              fee_denumerator: u64): u128 {
        assert(amount_in > 0, ERROR_ROUTER_PARAMETER_INVALID);
        assert(reserve_in > 0 && reserve_out > 0, ERROR_ROUTER_PARAMETER_INVALID);

        assert(fee_denumerator > 0 && fee_numerator > 0, ERROR_SWAP_FEE_ALGORITHM_INVALID);
        assert(fee_denumerator > fee_numerator, ERROR_SWAP_FEE_ALGORITHM_INVALID);

//        let amount_in_with_fee = amount_in * 997;
//        let denominator = reserve_in * 1000 + amount_in_with_fee;
//        let r = SafeMath::safe_mul_div_u128(amount_in_with_fee, reserve_out, denominator);
//        r

        let amount_in_with_fee = amount_in * ((fee_denumerator - fee_numerator) as u128);
        let denominator = reserve_in * (fee_denumerator as u128) + amount_in_with_fee;
        let r = SafeMath::safe_mul_div_u128(amount_in_with_fee, reserve_out, denominator);
        r
    }

    public fun get_amount_in_without_fee(amount_out: u128, reserve_in: u128, reserve_out: u128): u128 {
        assert(amount_out > 0, ERROR_ROUTER_PARAMETER_INVALID);
        assert(reserve_in > 0 && reserve_out > 0, ERROR_ROUTER_PARAMETER_INVALID);
        let denominator = (reserve_out - amount_out);
        let r = SafeMath::safe_mul_div_u128(amount_out, reserve_in, denominator);
        r + 1
    }

    public fun get_amount_out_without_fee(amount_in: u128, reserve_in: u128, reserve_out: u128): u128 {
        assert(amount_in > 0, ERROR_ROUTER_PARAMETER_INVALID);
        assert(reserve_in > 0 && reserve_out > 0, ERROR_ROUTER_PARAMETER_INVALID);

        let denominator = reserve_in  + amount_in;
        let r = SafeMath::safe_mul_div_u128(amount_in, reserve_out, denominator);

        r
    }
}
}
